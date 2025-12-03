// Cloud Function pour analyser les photos de panne avec Gemini Vision
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { GoogleGenAI } = require('@google/genai');
const axios = require('axios'); // Nécessaire pour télécharger l'image depuis Supabase

// --- Initialisation ---
admin.initializeApp();
const db = admin.firestore();

// Le SDK Google Gen AI utilise l'environnement par défaut de Firebase Functions
// pour l'authentification (service account), pas besoin de clé API ici.
const ai = new GoogleGenAI({});

// --- Schéma JSON pour le résultat IA (garantit la structure) ---
const ANALYSIS_SCHEMA = {
  type: "object",
  properties: {
    recommended_tools: {
      type: "array",
      description: "Liste des outils nécessaires pour la réparation.",
      items: { type: "string" }
    },
    estimated_price: {
      type: "string",
      description: "Fourchette de prix estimée en Dinars Tunisiens (TND), ex: 50 TND - 80 TND."
    },
    advice: {
      type: "string",
      description: "Conseils de sécurité ou étapes de dépannage initiales pour le client."
    }
  },
  required: ["recommended_tools", "estimated_price", "advice"]
};

// --- Fonction utilitaire pour télécharger l'image et la convertir en Base64 ---
/**
 * Télécharge une image depuis une URL publique et la convertit en Base64.
 * @param {string} url L'URL publique Supabase de l'image.
 * @returns {Promise<{inlineData: {data: string, mimeType: string}}>} L'objet image pour l'API Gemini.
 */
async function urlToGenerativePart(url) {
  try {
    const response = await axios.get(url, { responseType: 'arraybuffer' });
    const contentType = response.headers['content-type'] || 'image/jpeg';
    const base64Data = Buffer.from(response.data).toString('base64');
    
    return {
      inlineData: {
        data: base64Data,
        mimeType: contentType,
      },
    };
  } catch (error) {
    console.error("Erreur lors du téléchargement de l'image:", error);
    throw new Error(`Impossible de télécharger ou de convertir l'image à partir de ${url}`);
  }
}

// --- Cloud Function Trigger ---
/**
 * Se déclenche lorsqu'un nouveau document est créé dans la collection 'jobs'.
 * Utilise Gemini Vision pour analyser l'image et met à jour le document Firestore.
 */
exports.jobAnalysisTrigger = functions.firestore
  .document('jobs/{jobId}')
  .onCreate(async (snapshot, context) => {
    const jobData = snapshot.data();
    const jobId = context.params.jobId;
    const { imageUrl, description } = jobData;

    console.log(`[Trigger] Nouveau Job créé avec ID: ${jobId}`);

    if (!imageUrl) {
      console.warn('[Trigger] Pas d\'imageUrl trouvée. Sortie de la fonction.');
      return snapshot.ref.update({ status: 'error', error_message: 'Image URL manquante' });
    }
    
    // Prompt système précis
    const SYSTEM_PROMPT = `Tu es un expert bricoleur tunisien. Analyse cette photo de panne (avec la description: ${description}). 
    Liste les outils spécifiques nécessaires pour la réparation et estime une fourchette de prix de réparation en Dinars Tunisiens (TND). 
    Réponds uniquement au format JSON strict.`;

    try {
      // Préparation de l'image pour l'API
      const imagePart = await urlToGenerativePart(imageUrl);

      // Appel à Gemini Vision pour l'analyse
      const response = await ai.models.generateContent({
        model: "gemini-2.5-flash",
        contents: [
          { role: "user", parts: [{ text: SYSTEM_PROMPT }, imagePart] }
        ],
        config: {
          responseMimeType: "application/json",
          responseSchema: ANALYSIS_SCHEMA
        }
      });
      
      // Extraction et validation du JSON
      const jsonResponseText = response.text.trim();
      const aiResult = JSON.parse(jsonResponseText);

      console.log(`[Gemini] Analyse réussie. Outils: ${aiResult.recommended_tools.join(', ')}`);

      // Mise à jour du document Firestore
      return snapshot.ref.update({
        status: 'analyzed',
        ai_result: aiResult, // Sauvegarde le JSON structuré
        // Optionnel: 'ai_raw_response': jsonResponseText // Pour le débogage
      });

    } catch (error) {
      console.error(`[Erreur Fatale] Échec de l'analyse ou de la mise à jour pour le job ${jobId}:`, error);
      
      // Mise à jour du statut en cas d'erreur
      return snapshot.ref.update({
        status: 'error',
        error_message: error.message || 'Erreur inconnue lors de l\'analyse IA'
      });
    }
  });
