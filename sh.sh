#!/bin/bash

# ==========================================
# FIX IMPORTS & TYPES - Snay3ia
# Corrige les chemins d'import (3 niveaux ../../../)
# Corrige le typage TypeScript strict pour UserProfile.
# ==========================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Correction des chemins et des types TypeScript...${NC}"

# ==========================================
# 1. RegisterComponent
# Chemin: src/app/features/auth/register/register.component.ts
# Profondeur: 3 niveaux
# ==========================================
REGISTER_FILE="src/app/features/auth/register/register.component.ts"
echo -e "  - Correction ${REGISTER_FILE}..."

cat <<EOF > "$REGISTER_FILE"
import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { createUserWithEmailAndPassword, updateProfile } from 'firebase/auth';
import { auth } from '../../../core/firebase.config'; // CORRECT: 3 niveaux

@Component({
  selector: 'app-register',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './register.component.html'
})
export class RegisterComponent {
  private router = inject(Router);
  
  fullName = '';
  email = '';
  password = '';
  confirmPassword = '';
  errorMessage = '';
  isLoading = false;

  async onRegister() {
    if (this.password !== this.confirmPassword) {
      this.errorMessage = 'Les mots de passe ne correspondent pas.';
      return;
    }

    this.isLoading = true;
    this.errorMessage = '';
    
    try {
      const userCredential = await createUserWithEmailAndPassword(auth, this.email, this.password);
      
      if (this.fullName) {
        await updateProfile(userCredential.user, {
          displayName: this.fullName
        });
      }

      this.router.navigate(['/role-select']);
    } catch (error: any) {
      console.error('Registration error', error);
      switch(error.code) {
        case 'auth/email-already-in-use':
          this.errorMessage = 'Cet email est déjà utilisé.';
          break;
        case 'auth/weak-password':
          this.errorMessage = 'Le mot de passe doit contenir au moins 6 caractères.';
          break;
        case 'auth/invalid-email':
          this.errorMessage = 'Adresse email invalide.';
          break;
        default:
          this.errorMessage = 'Erreur lors de l\\'inscription (' + error.code + ').';
      }
    } finally {
      this.isLoading = false;
    }
  }
}
EOF

# ==========================================
# 2. UserProfileComponent
# Chemin: src/app/features/dashboard/user-profile/user-profile.component.ts
# Profondeur: 3 niveaux
# Correctif TS: Typage explicite du subscribe
# ==========================================
UP_FILE="src/app/features/dashboard/user-profile/user-profile.component.ts"
echo -e "  - Correction ${UP_FILE} (Imports + Typage)..."

cat <<EOF > "$UP_FILE"
import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { auth, db } from '../../../core/firebase.config'; // CORRECT: 3 niveaux
import { collection, query, where, onSnapshot, Unsubscribe, updateDoc, doc } from 'firebase/firestore';
import { UserService, WorkerProfile } from '../../../core/services/user.service'; // CORRECT: 3 niveaux

interface Proposal {
  workerId: string;
  workerName: string;
  price: number;
  status: string;
}

interface Job {
  id: string;
  description: string;
  imageUrl?: string;
  imageUrls?: string[];
  status: string;
  createdAt: any;
  proposals?: Proposal[];
}

@Component({
  selector: 'app-user-profile',
  standalone: true,
  imports: [CommonModule, DatePipe],
  template: \`
    <div class="space-y-6 pb-20 relative">
      <div class="bg-blue-600 rounded-2xl p-6 text-white shadow-lg relative overflow-hidden">
        <div class="relative z-10">
          <h3 class="text-2xl font-bold">Mes Pannes</h3>
          <p class="opacity-90 text-blue-100">Gérez vos demandes et les artisans.</p>
        </div>
        <div class="absolute right-[-20px] top-[-20px] w-32 h-32 bg-white opacity-10 rounded-full blur-2xl"></div>
      </div>

      @if (!isLoading && jobs.length > 0) {
        <div class="space-y-6">
          @for (job of jobs; track job.id) {
            <div class="bg-white p-4 rounded-xl shadow-sm border border-gray-100">
              
              <!-- Info Job -->
              <div class="flex gap-4 items-start mb-4">
                <div class="w-20 h-20 flex-shrink-0 bg-gray-100 rounded-lg overflow-hidden border border-gray-200 relative">
                  @if (isVideo(getMainMedia(job))) {
                     <div class="w-full h-full bg-black flex items-center justify-center"><span class="text-2xl">▶️</span></div>
                  } @else {
                     <img [src]="getMainMedia(job)" alt="Panne" class="w-full h-full object-cover">
                  }
                </div>
                <div class="flex-grow min-w-0">
                  <div class="flex justify-between items-start mb-1">
                    <span [class]="getStatusClass(job.status)" class="px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider">
                      {{ getStatusLabel(job.status) }}
                    </span>
                    <span class="text-xs text-gray-400 ml-2">{{ formatTimestamp(job.createdAt) | date:'dd MMM' }}</span>
                  </div>
                  <p class="text-gray-800 font-medium text-sm line-clamp-2">{{ job.description }}</p>
                </div>
              </div>

              <!-- SECTION PROPOSITIONS -->
              @if (job.status === 'analyzing' && job.proposals && job.proposals.length > 0) {
                <div class="border-t border-gray-100 pt-3">
                  <h5 class="text-sm font-bold text-gray-700 mb-3 flex items-center">
                    <span class="bg-red-100 text-red-600 rounded-full w-5 h-5 flex items-center justify-center text-xs mr-2">{{ job.proposals.length }}</span>
                    Artisans intéressés
                  </h5>
                  
                  <div class="space-y-3">
                    @for (proposal of job.proposals; track proposal.workerId) {
                      <div class="bg-gray-50 p-3 rounded-lg flex justify-between items-center">
                        <div (click)="viewWorkerProfile(proposal.workerId)" class="cursor-pointer">
                          <p class="font-bold text-gray-800 text-sm hover:underline">{{ proposal.workerName }}</p>
                          <p class="text-green-600 font-bold text-sm">{{ proposal.price }} TND</p>
                        </div>
                        <div class="flex gap-2">
                          <button (click)="viewWorkerProfile(proposal.workerId)" class="text-xs bg-white border border-gray-300 text-gray-600 px-3 py-1.5 rounded-md">Profil</button>
                          <button (click)="acceptProposal(job, proposal)" class="text-xs bg-green-600 text-white px-3 py-1.5 rounded-md font-bold shadow-sm">Accepter</button>
                        </div>
                      </div>
                    }
                  </div>
                </div>
              }
              
              @if (job.status === 'analyzing' && (!job.proposals || job.proposals.length === 0)) {
                <div class="bg-yellow-50 text-yellow-800 text-xs p-2 rounded text-center">
                  En attente de propositions d'artisans...
                </div>
              }
            </div>
          }
        </div>
      }

      <!-- MODALE PROFIL ARTISAN -->
      @if (selectedWorker) {
        <div class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm animate-fade-in">
          <div class="bg-white w-full sm:w-[400px] rounded-t-3xl sm:rounded-2xl shadow-2xl overflow-hidden animate-slide-up">
            <div class="bg-blue-600 p-6 text-white text-center relative">
              <button (click)="closeProfile()" class="absolute top-4 right-4 text-white/80 hover:text-white">✕</button>
              <div class="w-20 h-20 bg-white text-blue-600 rounded-full mx-auto flex items-center justify-center text-3xl font-bold mb-3 shadow-md">
                {{ selectedWorker.displayName.charAt(0) }}
              </div>
              <h2 class="text-xl font-bold">{{ selectedWorker.displayName }}</h2>
              <p class="text-blue-100 text-sm">{{ selectedWorker.specialty }}</p>
              <div class="flex justify-center gap-1 mt-2 text-yellow-300">
                <span>★</span><span>{{ selectedWorker.rating }}</span> <span class="text-white/60 text-xs">({{ selectedWorker.reviews.length }} avis)</span>
              </div>
            </div>
            
            <div class="p-6 max-h-[50vh] overflow-y-auto">
              <h3 class="font-bold text-gray-800 mb-3">Derniers avis clients</h3>
              <div class="space-y-4">
                @for (review of selectedWorker.reviews; track review.author) {
                  <div class="border-b border-gray-100 pb-3 last:border-0">
                    <div class="flex justify-between items-center mb-1">
                      <span class="font-bold text-sm text-gray-700">{{ review.author }}</span>
                      <span class="text-yellow-500 text-xs">★ {{ review.rating }}</span>
                    </div>
                    <p class="text-gray-500 text-xs italic">"{{ review.comment }}"</p>
                  </div>
                }
              </div>
            </div>
            
            <div class="p-4 border-t border-gray-100 bg-gray-50 text-center">
              <button (click)="closeProfile()" class="text-gray-500 font-medium text-sm">Fermer</button>
            </div>
          </div>
        </div>
      }
    </div>
  \`
})
export class UserProfileComponent implements OnInit, OnDestroy {
  jobs: Job[] = [];
  isLoading = true;
  selectedWorker: WorkerProfile | null = null;
  
  private unsubscribe: Unsubscribe | null = null;
  private cdr = inject(ChangeDetectorRef);
  private userService = inject(UserService);

  ngOnInit() {
    const user = auth.currentUser;
    if (!user) return;

    const jobsQuery = query(collection(db, 'jobs'), where('userId', '==', user.uid));

    this.unsubscribe = onSnapshot(jobsQuery, (snapshot) => {
      const fetchedJobs = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as Job[];
      this.jobs = fetchedJobs.sort((a, b) => this.formatTimestamp(b.createdAt).getTime() - this.formatTimestamp(a.createdAt).getTime());
      this.isLoading = false;
      this.cdr.detectChanges();
    });
  }

  viewWorkerProfile(workerId: string) {
    // Typage explicite pour éviter l'erreur TS7006/TS2571
    this.userService.getWorkerProfile(workerId).subscribe((profile: WorkerProfile) => {
      this.selectedWorker = profile;
      this.cdr.detectChanges();
    });
  }

  closeProfile() {
    this.selectedWorker = null;
    this.cdr.detectChanges();
  }

  async acceptProposal(job: Job, proposal: Proposal) {
    if(!confirm(\`Accepter le devis de \${proposal.workerName} pour \${proposal.price} TND ?\`)) return;

    try {
      await updateDoc(doc(db, 'jobs', job.id), {
        status: 'assigned',
        workerId: proposal.workerId,
        acceptedPrice: proposal.price,
        acceptedAt: new Date()
      });
      alert("Artisan validé ! Il sera notifié.");
    } catch (e) {
      console.error(e);
      alert("Erreur lors de la validation.");
    }
  }

  getMainMedia(job: Job): string {
    if (job.imageUrls && job.imageUrls.length > 0) return job.imageUrls[0];
    return job.imageUrl || '';
  }

  isVideo(url: string): boolean {
    if (!url) return false;
    return !!url.match(/\.(mp4|webm|ogg|mov|avi|mkv)(\?.*)?$/i);
  }

  getStatusLabel(status: string): string {
    const labels: any = { 'analyzing': 'En cours', 'assigned': 'Confirmé', 'completed': 'Terminé' };
    return labels[status] || status;
  }

  getStatusClass(status: string): string {
    return status === 'assigned' ? 'bg-green-100 text-green-700' : 'bg-blue-100 text-blue-700';
  }

  formatTimestamp(timestamp: any): Date {
    if (timestamp && typeof timestamp.toDate === 'function') return timestamp.toDate();
    return timestamp ? new Date(timestamp) : new Date();
  }

  ngOnDestroy() { if (this.unsubscribe) this.unsubscribe(); }
}
EOF

# ==========================================
# 3. ArtisanListComponent
# Chemin: src/app/features/pro-search/artisan-list/artisan-list.component.ts
# Profondeur: 3 niveaux
# ==========================================
ARTISAN_FILE="src/app/features/pro-search/artisan-list/artisan-list.component.ts"
echo -e "  - Correction ${ARTISAN_FILE}..."

cat <<EOF > "$ARTISAN_FILE"
import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { collection, query, where, onSnapshot, Firestore } from 'firebase/firestore';
import { db } from '../../../core/firebase.config'; // CORRECT: 3 niveaux

interface Artisan {
  id: string;
  name: string;
  specialty: string;
  city: string;
  rating: number;
}

@Component({
  selector: 'app-artisan-list',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './artisan-list.component.html',
  styleUrl: './artisan-list.component.scss',
})
export class ArtisanListComponent implements OnInit {
  artisans: Artisan[] = [];
  isLoading = true;
  private firestore: Firestore = db;

  ngOnInit(): void {
    this.loadArtisans();
  }

  loadArtisans(): void {
    const artisansCollection = collection(this.firestore, 'artisans');
    onSnapshot(artisansCollection, (snapshot) => {
      const artisansData: Artisan[] = [];
      snapshot.forEach(doc => {
        artisansData.push({ 
          id: doc.id, 
          ...(doc.data() as Omit<Artisan, 'id'>) 
        });
      });
      this.artisans = artisansData;
      this.isLoading = false;
    }, (error) => {
      console.error("[ArtisanList] Erreur de chargement des artisans:", error);
      this.isLoading = false;
    });
  }
}
EOF

echo -e "${GREEN}✅ Chemins d'importation et Types corrigés !${NC}"
echo -e "Relancez 'ng serve' si le watcher ne détecte pas les changements."