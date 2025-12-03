import { Injectable } from '@angular/core';
import { collection, addDoc, Firestore } from 'firebase/firestore';
import { supabase, STORAGE_BUCKET_BREAKDOWNS } from '../supabase.client';
import { db, auth } from '../firebase.config';

interface Job {
  description: string;
  imageUrls: string[]; // Support multi-images
  status: 'pending' | 'analyzing' | 'assigned' | 'completed';
  createdAt: Date;
  userId: string;
  userEmail?: string;
}

@Injectable({
  providedIn: 'root'
})
export class Sannay3iService {
  private firestore: Firestore = db;
  private jobsCollection = collection(this.firestore, 'jobs');

  private generateId(): string {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
  }

  /**
   * Upload multiple files and create job
   */
  async createJob(description: string, files: File[]): Promise<string> {
    console.log('[Service] Début createJob avec', files.length, 'fichiers.');

    const user = auth.currentUser;
    if (!user) {
      throw new Error("Vous devez être connecté.");
    }

    try {
      const uploadedUrls: string[] = [];

      // 1. Upload de chaque fichier en parallèle avec gestion d'erreur individuelle
      const uploadPromises = files.map(async (file) => {
        try {
          const fileExt = file.name.split('.').pop();
          const fileName = `${user.uid}/${this.generateId()}.${fileExt}`;
          
          // Upload vers Supabase
          const { error: uploadError } = await supabase.storage
            .from(STORAGE_BUCKET_BREAKDOWNS)
            .upload(fileName, file, { cacheControl: '3600', upsert: false });

          if (uploadError) {
            console.error(`Erreur upload Supabase pour ${file.name}:`, uploadError);
            throw new Error(`Échec upload de ${file.name}. Vérifiez la taille (<10Mo).`);
          }

          const { data: urlData } = supabase.storage
            .from(STORAGE_BUCKET_BREAKDOWNS)
            .getPublicUrl(fileName);
            
          return urlData.publicUrl;
        } catch (err: any) {
          // Si c'est une erreur de parsing JSON (le cas classique du 400 Bad Request HTML)
          if (err.message && err.message.includes('Unexpected token')) {
             throw new Error(`Le fichier "${file.name}" est trop volumineux pour le serveur.`);
          }
          throw err;
        }
      });

      // Attendre que tous les uploads soient finis
      const results = await Promise.all(uploadPromises);
      uploadedUrls.push(...results);
      
      console.log('[Service] URLs obtenues:', uploadedUrls);

      // 2. Sauvegarde Firestore
      const newJob: Job = {
        description: description,
        imageUrls: uploadedUrls, // Tableau d'URLs
        status: 'analyzing', // Deviendra "Validé" côté affichage
        createdAt: new Date(),
        userId: user.uid,
        userEmail: user.email || 'Anonyme'
      };

      const docRef = await addDoc(this.jobsCollection, newJob);
      return docRef.id;

    } catch (error: any) {
      console.error('[Service] EXCEPTION:', error);
      throw error;
    }
  }
}
