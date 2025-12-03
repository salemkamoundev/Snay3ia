#!/bin/bash

# ==========================================
# UPDATE USER PROFILE - Snay3ia
# Transforme l'espace client statique en liste dynamique des pannes.
# Connecté à Firestore en temps réel.
# CORRECTION : Tri côté client (évite l'erreur d'index) + ChangeDetectorRef.
# UPDATE : Les demandes sont affichées comme "Validé" automatiquement.
# ==========================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

COMPONENT_DIR="src/app/features/dashboard/user-profile"
COMPONENT_TS="$COMPONENT_DIR/user-profile.component.ts"

# Création du dossier si inexistant (sécurité)
mkdir -p "$COMPONENT_DIR"

echo -e "${BLUE}📋 Mise à jour du UserProfileComponent (Status Validé)...${NC}"

cat <<EOF > "$COMPONENT_TS"
import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { auth, db } from '../../../../core/firebase.config';
import { collection, query, where, onSnapshot, Unsubscribe } from 'firebase/firestore';

interface Job {
  id: string;
  description: string;
  imageUrl: string;
  status: string;
  createdAt: any; // Timestamp or Date
  ai_result?: any;
}

@Component({
  selector: 'app-user-profile',
  standalone: true,
  imports: [CommonModule, DatePipe],
  template: \`
    <div class="space-y-6 pb-20">
      <!-- En-tête -->
      <div class="bg-blue-600 rounded-2xl p-6 text-white shadow-lg relative overflow-hidden">
        <div class="relative z-10">
          <h3 class="text-2xl font-bold">Mes Pannes</h3>
          <p class="opacity-90 text-blue-100">Suivez l'état de vos réparations en temps réel.</p>
        </div>
        <!-- Décoration fond -->
        <div class="absolute right-[-20px] top-[-20px] w-32 h-32 bg-white opacity-10 rounded-full blur-2xl"></div>
      </div>

      <!-- État Chargement -->
      @if (isLoading) {
        <div class="flex justify-center py-10">
          <div class="animate-spin h-8 w-8 border-4 border-blue-500 border-t-transparent rounded-full"></div>
        </div>
      }

      <!-- État Vide -->
      @if (!isLoading && jobs.length === 0) {
        <div class="bg-white rounded-xl p-8 shadow-sm border border-dashed border-gray-300 text-center">
          <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4 text-3xl">
            🔧
          </div>
          <h4 class="font-bold text-gray-800 mb-2">Aucune demande</h4>
          <p class="text-gray-500 text-sm">
            Vous n'avez pas encore signalé de panne.<br>
            Utilisez le bouton <strong>"Demander"</strong> ci-dessous.
          </p>
        </div>
      }

      <!-- Liste des Jobs -->
      @if (!isLoading && jobs.length > 0) {
        <div class="space-y-4">
          @for (job of jobs; track job.id) {
            <div class="bg-white p-4 rounded-xl shadow-sm border border-gray-100 hover:shadow-md transition-shadow flex gap-4 items-start">
              
              <!-- Image Miniature -->
              <div class="w-20 h-20 flex-shrink-0 bg-gray-100 rounded-lg overflow-hidden border border-gray-200">
                <img [src]="job.imageUrl" alt="Panne" class="w-full h-full object-cover">
              </div>

              <!-- Contenu -->
              <div class="flex-grow min-w-0">
                <div class="flex justify-between items-start mb-1">
                  <span [class]="getStatusClass(job.status)" class="px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider">
                    {{ getStatusLabel(job.status) }}
                  </span>
                  <span class="text-xs text-gray-400 whitespace-nowrap ml-2">
                    {{ formatTimestamp(job.createdAt) | date:'dd MMM, HH:mm' }}
                  </span>
                </div>
                
                <p class="text-gray-800 font-medium text-sm line-clamp-2 mb-2">
                  {{ job.description }}
                </p>
              </div>

            </div>
          }
        </div>
      }
    </div>
  \`
})
export class UserProfileComponent implements OnInit, OnDestroy {
  jobs: Job[] = [];
  isLoading = true;
  private unsubscribe: Unsubscribe | null = null;
  private cdr = inject(ChangeDetectorRef); // Injection pour forcer la mise à jour UI

  ngOnInit() {
    this.fetchUserJobs();
  }

  fetchUserJobs() {
    const user = auth.currentUser;
    if (!user) {
      this.isLoading = false;
      return;
    }

    // Requête simplifiée : Seulement filtrage par user (pas de orderBy pour éviter l'erreur d'index)
    const jobsQuery = query(
      collection(db, 'jobs'),
      where('userId', '==', user.uid)
    );

    this.unsubscribe = onSnapshot(jobsQuery, (snapshot) => {
      // Transformation des données
      const fetchedJobs = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })) as Job[];

      // Tri côté client (JavaScript)
      this.jobs = fetchedJobs.sort((a, b) => {
        const dateA = this.formatTimestamp(a.createdAt).getTime();
        const dateB = this.formatTimestamp(b.createdAt).getTime();
        return dateB - dateA; // Plus récent en premier
      });

      this.isLoading = false;
      this.cdr.detectChanges(); // Forcer la mise à jour de l'affichage
      
    }, (error) => {
      console.error("Erreur récupération jobs:", error);
      this.isLoading = false;
      this.cdr.detectChanges();
    });
  }

  // Helpers pour l'affichage
  getStatusLabel(status: string): string {
    const labels: any = {
      'pending': 'Validé',    // Changé en Validé
      'analyzing': 'Validé',  // Changé en Validé (pour l'ajout automatique)
      'analyzed': 'Validé',
      'assigned': 'Artisan en route',
      'completed': 'Terminé'
    };
    return labels[status] || status;
  }

  getStatusClass(status: string): string {
    switch (status) {
      case 'pending':
      case 'analyzing':
      case 'analyzed':
        return 'bg-green-100 text-green-700'; // Vert pour Validé
      case 'assigned':
        return 'bg-blue-100 text-blue-700';
      case 'completed': 
        return 'bg-gray-100 text-gray-700';
      default: return 'bg-gray-100 text-gray-600';
    }
  }

  formatTimestamp(timestamp: any): Date {
    // Conversion Timestamp Firestore -> Date JS
    if (timestamp && typeof timestamp.toDate === 'function') {
      return timestamp.toDate();
    }
    // Si c'est null ou undefined, on retourne la date actuelle pour éviter le crash
    if (!timestamp) return new Date();
    
    return new Date(timestamp);
  }

  ngOnDestroy() {
    if (this.unsubscribe) {
      this.unsubscribe();
    }
  }
}
EOF

echo -e "${GREEN}✅ UserProfileComponent mis à jour !${NC}"
echo -e "Les demandes s'affichent maintenant comme 'Validé' immédiatement."