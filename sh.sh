#!/bin/bash

# ==========================================
# SETUP ROLE PERSISTENCE & ROUTING FIX - Snay3ia
# 1. Enregistre le rôle dans Firestore.
# 2. Charge le rôle et redirige vers la bonne page (Client vs Missions).
# 3. Configure la page "Missions" pour les artisans (Détails + Proposition).
# ==========================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Configuration Persistance, Routage et Missions...${NC}"

# ==========================================
# 1. MISE À JOUR DE LA SÉLECTION DE RÔLE
# ==========================================
ROLE_DIR="src/app/features/auth/role-selection"
mkdir -p "$ROLE_DIR"

echo -e "  - Mise à jour RoleSelectionComponent..."

cat <<EOF > "$ROLE_DIR/role-selection.component.ts"
import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { auth, db } from '../../../core/firebase.config';
import { doc, setDoc } from 'firebase/firestore';

@Component({
  selector: 'app-role-selection',
  standalone: true,
  imports: [CommonModule],
  template: \`
    <div class="min-h-screen bg-gradient-to-br from-blue-600 to-blue-800 flex flex-col items-center justify-center p-6 text-white">
      <h1 class="text-3xl font-bold mb-2">Bienvenue sur Snay3ia</h1>
      <p class="text-blue-100 mb-10 text-center">Pour commencer, dites-nous qui vous êtes.</p>

      @if (isLoading) {
        <div class="text-white text-center">
          <div class="animate-spin h-8 w-8 border-4 border-white border-t-transparent rounded-full mx-auto mb-2"></div>
          Enregistrement...
        </div>
      } @else {
        <div class="grid gap-6 w-full max-w-md animate-fade-in">
          <button (click)="selectRole('client')" class="bg-white text-blue-900 p-6 rounded-2xl shadow-xl hover:scale-105 transition transform flex items-center gap-4 group">
            <div class="bg-blue-100 p-4 rounded-full group-hover:bg-blue-200 transition">
              <span class="text-3xl">🏠</span>
            </div>
            <div class="text-left">
              <h3 class="text-xl font-bold">Je suis Client</h3>
              <p class="text-sm text-gray-500">Je cherche un artisan.</p>
            </div>
          </button>

          <button (click)="selectRole('worker')" class="bg-white text-green-900 p-6 rounded-2xl shadow-xl hover:scale-105 transition transform flex items-center gap-4 group">
            <div class="bg-green-100 p-4 rounded-full group-hover:bg-green-200 transition">
              <span class="text-3xl">🛠️</span>
            </div>
            <div class="text-left">
              <h3 class="text-xl font-bold">Je suis Artisan</h3>
              <p class="text-sm text-gray-500">Je propose mes services.</p>
            </div>
          </button>
        </div>
      }
    </div>
  \`
})
export class RoleSelectionComponent {
  private router = inject(Router);
  isLoading = false;

  async selectRole(role: 'client' | 'worker') {
    const user = auth.currentUser;
    if (!user) {
      this.router.navigate(['/login']);
      return;
    }

    this.isLoading = true;

    try {
      await setDoc(doc(db, 'users', user.uid), {
        email: user.email,
        displayName: user.displayName || '',
        role: role,
        createdAt: new Date(),
        ...(role === 'worker' ? { specialty: 'Général', rating: 5, completedJobs: 0 } : {})
      }, { merge: true });

      // Redirection immédiate vers la bonne section
      const targetRoute = role === 'worker' ? '/dashboard/missions' : '/dashboard/client';
      this.router.navigate([targetRoute]);
      
    } catch (error) {
      console.error("Erreur sauvegarde rôle:", error);
      this.isLoading = false;
    }
  }
}
EOF

# ==========================================
# 2. MISE À JOUR DU DASHBOARD (Redirection Intelligente)
# ==========================================
DASHBOARD_DIR="src/app/features/dashboard"
mkdir -p "$DASHBOARD_DIR"

echo -e "  - Mise à jour DashboardComponent (Logique de routage)..."

cat <<EOF > "$DASHBOARD_DIR/dashboard.component.ts"
import { Component, inject, OnInit, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet, RouterLink, RouterLinkActive, Router } from '@angular/router';
import { auth, db } from '../../core/firebase.config';
import { signOut, onAuthStateChanged } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { JobRequestComponent } from '../job-request/job-request/job-request.component';

@Component({
  selector: 'app-dashboard',
  standalone: true,
  imports: [CommonModule, RouterOutlet, RouterLink, RouterLinkActive, JobRequestComponent],
  templateUrl: './dashboard.component.html',
  styleUrl: './dashboard.component.scss'
})
export class DashboardComponent implements OnInit {
  private router = inject(Router);
  private cdr = inject(ChangeDetectorRef);
  
  userEmail = 'Utilisateur';
  userType: 'client' | 'worker' | 'loading' = 'loading';
  isJobModalOpen = false;

  ngOnInit() {
    onAuthStateChanged(auth, async (user) => {
      if (!user) {
        this.router.navigate(['/login']);
        return;
      }
      this.userEmail = user.email || 'Utilisateur';

      try {
        const userDoc = await getDoc(doc(db, 'users', user.uid));
        
        if (userDoc.exists() && userDoc.data()['role']) {
          this.userType = userDoc.data()['role'];
          console.log("Rôle détecté:", this.userType);

          // REDIRECTION INTELLIGENTE
          // Si l'URL est juste '/dashboard', on redirige vers la home spécifique au rôle
          if (this.router.url === '/dashboard' || this.router.url === '/dashboard/') {
            if (this.userType === 'worker') {
              this.router.navigate(['/dashboard', 'missions']);
            } else {
              this.router.navigate(['/dashboard', 'client']);
            }
          }
        } else {
          this.router.navigate(['/role-select']);
        }
        this.cdr.detectChanges();
      } catch (error) {
        console.error("Erreur Dashboard:", error);
        this.router.navigate(['/role-select']);
      }
    });
  }

  openJobModal() { this.isJobModalOpen = true; this.cdr.detectChanges(); }
  closeJobModal() { this.isJobModalOpen = false; this.cdr.detectChanges(); }

  async logout() {
    await signOut(auth);
    this.router.navigate(['/']);
  }
}
EOF

# HTML Dashboard (Menu adapté)
cat <<EOF > "$DASHBOARD_DIR/dashboard.component.html"
@if (userType === 'loading') {
  <div class="flex h-screen items-center justify-center bg-gray-50">
    <div class="animate-spin h-10 w-10 border-4 border-blue-600 border-t-transparent rounded-full"></div>
  </div>
} @else {
  <div class="flex flex-col h-screen bg-gray-50 relative">
    
    <header class="bg-white shadow-sm p-4 flex justify-between items-center z-10">
      <div class="flex items-center">
        <div class="w-10 h-10 rounded-full bg-blue-100 text-blue-600 flex items-center justify-center font-bold mr-3">
          {{ userEmail.charAt(0).toUpperCase() }}
        </div>
        <div>
          <h2 class="text-sm font-bold text-gray-800">Bonjour,</h2>
          <p class="text-xs text-gray-500 capitalize">{{ userType === 'worker' ? 'Artisan' : 'Client' }}</p>
        </div>
      </div>
      <button (click)="logout()" class="text-red-500 hover:bg-red-50 p-2 rounded-full transition">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1"></path></svg>
      </button>
    </header>

    <main class="flex-grow overflow-y-auto p-4 pb-24">
      <router-outlet></router-outlet>
    </main>

    @if (isJobModalOpen) {
      <div class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm animate-fade-in">
        <div class="bg-white w-full sm:w-[500px] h-[90%] sm:h-auto sm:max-h-[85vh] rounded-t-3xl sm:rounded-2xl shadow-2xl flex flex-col overflow-hidden animate-slide-up">
          <div class="p-4 border-b flex justify-between items-center bg-gray-50">
            <h3 class="font-bold text-gray-800">Nouvelle Demande</h3>
            <button (click)="closeJobModal()" class="p-2 bg-gray-200 rounded-full hover:bg-gray-300 transition">✕</button>
          </div>
          <div class="flex-grow overflow-y-auto p-2">
            <app-job-request></app-job-request>
          </div>
        </div>
      </div>
    }

    <nav class="fixed bottom-0 left-0 w-full bg-white border-t border-gray-200 px-6 py-3 flex justify-between items-center text-xs font-medium text-gray-500 z-20">
      
      <!-- LIEN ACCUEIL (Dynamique selon le rôle) -->
      <a [routerLink]="['/dashboard', userType === 'worker' ? 'missions' : 'client']" routerLinkActive="text-blue-600" class="flex flex-col items-center gap-1">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path></svg>
        <span>Accueil</span>
      </a>

      <!-- BOUTON CENTRAL (Conditionnel) -->
      @if (userType === 'client') {
        <button (click)="openJobModal()" class="flex flex-col items-center justify-center -mt-8 outline-none">
          <div class="w-14 h-14 bg-blue-600 rounded-full shadow-lg shadow-blue-300 flex items-center justify-center text-white transform active:scale-95 transition hover:scale-105">
            <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path></svg>
          </div>
          <span class="mt-1 text-blue-600 font-bold">Demander</span>
        </button>
      } @else {
        <!-- Pour l'artisan, accès à son historique -->
        <a routerLink="/dashboard/worker" routerLinkActive="text-blue-600" class="flex flex-col items-center gap-1">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path></svg>
          <span>Mon Profil</span>
        </a>
      }

      <a routerLink="/pro-search" routerLinkActive="text-blue-600" class="flex flex-col items-center gap-1">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path></svg>
        <span>Trouver</span>
      </a>

    </nav>
  </div>
}
EOF

# ==========================================
# 3. PAGE MISSIONS (Artisan) AVEC PROPOSITION
# ==========================================
MISSION_DIR="src/app/features/dashboard/mission-list"
mkdir -p "$MISSION_DIR"

echo -e "  - Configuration de la page Missions (Galerie + Devis)..."

cat <<EOF > "$MISSION_DIR/mission-list.component.ts"
import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { auth, db } from '../../../../core/firebase.config';
import { collection, query, where, onSnapshot, updateDoc, doc, arrayUnion, Unsubscribe } from 'firebase/firestore';

interface Job {
  id: string;
  description: string;
  imageUrl?: string;
  imageUrls?: string[];
  status: string;
  createdAt: any;
  userId: string;
  proposals?: any[];
}

@Component({
  selector: 'app-mission-list',
  standalone: true,
  imports: [CommonModule, DatePipe, FormsModule],
  template: \`
    <div class="space-y-6 pb-24">
      <div class="bg-green-600 rounded-2xl p-6 text-white shadow-lg relative overflow-hidden">
        <div class="relative z-10">
          <h3 class="text-2xl font-bold">Missions</h3>
          <p class="opacity-90 text-green-100">Proposez vos services aux clients.</p>
        </div>
        <div class="absolute right-[-20px] top-[-20px] w-32 h-32 bg-white opacity-10 rounded-full blur-2xl"></div>
      </div>

      @if (!isLoading && jobs.length > 0) {
        <div class="space-y-4">
          @for (job of jobs; track job.id) {
            <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
              
              <!-- Galerie Photo/Vidéo -->
              <div class="h-64 w-full bg-black flex overflow-x-auto snap-x no-scrollbar">
                @if (getAllMedia(job).length > 0) {
                  @for (media of getAllMedia(job); track media) {
                    <div class="w-full h-full flex-shrink-0 snap-center relative flex items-center justify-center bg-gray-900">
                      @if (isVideo(media)) {
                        <video [src]="media" controls class="max-w-full max-h-full"></video>
                      } @else {
                        <img [src]="media" class="w-full h-full object-cover">
                      }
                    </div>
                  }
                } @else {
                   <div class="w-full h-full flex items-center justify-center text-gray-400">Pas de média</div>
                }
              </div>
              
              <div class="p-5">
                <div class="flex justify-between mb-2">
                   <span class="text-xs font-bold text-gray-500">{{ formatTimestamp(job.createdAt) | date:'dd MMM HH:mm' }}</span>
                   <span class="text-xs bg-blue-100 text-blue-800 px-2 rounded-full font-bold">
                     {{ job.proposals?.length || 0 }} devis envoyés
                   </span>
                </div>
                
                <h4 class="font-bold text-gray-800 mb-1">Description du problème :</h4>
                <p class="text-gray-600 text-sm mb-4 bg-gray-50 p-3 rounded-lg">{{ job.description }}</p>
                
                @if (hasApplied(job)) {
                  <div class="bg-green-50 text-green-700 p-3 rounded-lg text-center font-bold text-sm border border-green-200">
                    ✅ Vous avez envoyé une proposition
                  </div>
                } @else {
                  <div class="border-t border-gray-100 pt-4">
                    <label class="text-xs font-bold text-gray-500 block mb-2">Envoyer un devis estimatif :</label>
                    <div class="flex gap-2">
                      <div class="relative flex-grow">
                        <input type="number" [(ngModel)]="offerPrice[job.id]" placeholder="0" class="w-full pl-3 pr-8 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-green-500 outline-none transition">
                        <span class="absolute right-3 top-2 text-gray-400 text-sm">TND</span>
                      </div>
                      <button (click)="applyToJob(job)" class="bg-green-600 text-white font-bold py-2 px-4 rounded-lg hover:bg-green-700 shadow-sm transition">
                        Envoyer
                      </button>
                    </div>
                  </div>
                }
              </div>
            </div>
          }
        </div>
      } @else if (!isLoading) {
        <div class="text-center py-10 text-gray-500">
          <div class="text-4xl mb-2">📭</div>
          Aucune mission disponible pour le moment.
        </div>
      }
    </div>
  \`
})
export class MissionListComponent implements OnInit, OnDestroy {
  jobs: Job[] = [];
  isLoading = true;
  offerPrice: { [key: string]: number } = {};
  
  private unsubscribe: Unsubscribe | null = null;
  private cdr = inject(ChangeDetectorRef);
  private currentUser = auth.currentUser;

  ngOnInit() {
    const jobsQuery = query(collection(db, 'jobs'), where('status', '==', 'analyzing'));
    
    this.unsubscribe = onSnapshot(jobsQuery, (snapshot) => {
      const fetchedJobs = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as Job[];
      this.jobs = fetchedJobs.sort((a, b) => this.formatTimestamp(b.createdAt).getTime() - this.formatTimestamp(a.createdAt).getTime());
      this.isLoading = false;
      this.cdr.detectChanges();
    });
  }

  hasApplied(job: Job): boolean {
    if (!this.currentUser || !job.proposals) return false;
    return job.proposals.some((p: any) => p.workerId === this.currentUser?.uid);
  }

  async applyToJob(job: Job) {
    if (!this.currentUser) return;
    const price = this.offerPrice[job.id];
    if (!price || price <= 0) {
      alert("Veuillez proposer un prix valide.");
      return;
    }

    try {
      const proposal = {
        workerId: this.currentUser.uid,
        workerName: this.currentUser.displayName || 'Artisan',
        price: price,
        status: 'pending',
        createdAt: new Date().toISOString()
      };

      await updateDoc(doc(db, 'jobs', job.id), {
        proposals: arrayUnion(proposal)
      });
      
      alert("Proposition envoyée au client !");
      this.offerPrice[job.id] = 0;
    } catch (e: any) {
      console.error(e);
      alert("Erreur: " + e.message);
    }
  }

  getAllMedia(job: Job): string[] {
    if (job.imageUrls && job.imageUrls.length > 0) return job.imageUrls;
    if (job.imageUrl) return [job.imageUrl];
    return [];
  }

  isVideo(url: string): boolean {
    if (!url) return false;
    return !!url.match(/\.(mp4|webm|ogg|mov|avi|mkv)(\?.*)?$/i);
  }

  formatTimestamp(timestamp: any): Date {
    if (timestamp && typeof timestamp.toDate === 'function') return timestamp.toDate();
    return timestamp ? new Date(timestamp) : new Date();
  }

  ngOnDestroy() { if (this.unsubscribe) this.unsubscribe(); }
}
EOF

# ==========================================
# 4. CONFIGURATION DES ROUTES
# ==========================================
ROUTES_FILE="src/app/app.routes.ts"
echo -e "  - Mise à jour des Routes (Suppression redirection forcée)..."

cat <<EOF > "$ROUTES_FILE"
import { Routes } from '@angular/router';
import { HomeComponent } from './features/home/home.component';
import { JobRequestComponent } from './features/job-request/job-request/job-request.component';
import { ArtisanListComponent } from './features/pro-search/artisan-list/artisan-list.component';
import { DashboardComponent } from './features/dashboard/dashboard.component';
import { UserProfileComponent } from './features/dashboard/user-profile/user-profile.component';
import { WorkerProfileComponent } from './features/dashboard/worker-profile/worker-profile.component';
import { MissionListComponent } from './features/dashboard/mission-list/mission-list.component';
import { RoleSelectionComponent } from './features/auth/role-selection/role-selection.component';
import { LoginComponent } from './features/auth/login/login.component';
import { RegisterComponent } from './features/auth/register/register.component';
import { authGuard } from './core/guards/auth.guard';

export const routes: Routes = [
  { path: '', component: HomeComponent, title: 'Snay3ia - Accueil' },
  { path: 'login', component: LoginComponent, title: 'Connexion' },
  { path: 'register', component: RegisterComponent, title: 'Inscription' },
  { path: 'role-select', component: RoleSelectionComponent, title: 'Snay3ia - Qui êtes-vous ?' },
  
  {
    path: 'dashboard',
    component: DashboardComponent,
    canActivate: [authGuard],
    children: [
      { path: 'client', component: UserProfileComponent, title: 'Mon Espace Client' },
      { path: 'worker', component: WorkerProfileComponent, title: 'Mon Profil Pro' },
      { path: 'missions', component: MissionListComponent, title: 'Missions Disponibles' },
      // PLUS DE REDIRECTION PAR DÉFAUT ICI : C'est le DashboardComponent qui gère.
    ]
  },

  { path: 'job-request', component: JobRequestComponent, title: 'Nouvelle Demande' },
  { path: 'pro-search', component: ArtisanListComponent, title: 'Trouver un Pro' },
  { path: '**', redirectTo: '' }
];
EOF

echo -e "${GREEN}✅ Tout est configuré !${NC}"
echo -e "- Les artisans sont redirigés vers /dashboard/missions"
echo -e "- Ils peuvent voir les détails (Photos/Vidéos) et envoyer un devis."