#!/bin/bash

# ==========================================
# SETUP ROLE PERSISTENCE - Snay3ia
# 1. Enregistre le rôle dans Firestore (collection 'users') lors de l'inscription.
# 2. Récupère le rôle depuis Firestore lors du chargement du Dashboard.
# CORRECTION PATH: ../../../core/firebase.config pour RoleSelection
# CORRECTION BLOCKAGE: Utilisation de onAuthStateChanged + ChangeDetectorRef.
# ==========================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔐 Configuration de la persistance des rôles (Firestore)...${NC}"

# ==========================================
# 1. MISE À JOUR DE LA SÉLECTION DE RÔLE
# ==========================================
ROLE_DIR="src/app/features/auth/role-selection"
# Création du dossier si inexistant (sécurité)
mkdir -p "$ROLE_DIR"

echo -e "  - Mise à jour RoleSelectionComponent (Save to Firestore)..."

cat <<EOF > "$ROLE_DIR/role-selection.component.ts"
import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { auth, db } from '../../../core/firebase.config'; // CHEMIN CORRIGÉ
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
          <!-- Option Client -->
          <button (click)="selectRole('client')" class="bg-white text-blue-900 p-6 rounded-2xl shadow-xl hover:scale-105 transition transform flex items-center gap-4 group">
            <div class="bg-blue-100 p-4 rounded-full group-hover:bg-blue-200 transition">
              <span class="text-3xl">🏠</span>
            </div>
            <div class="text-left">
              <h3 class="text-xl font-bold">Je suis Client</h3>
              <p class="text-sm text-gray-500">Je cherche un artisan.</p>
            </div>
          </button>

          <!-- Option Artisan -->
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
      alert("Erreur : Utilisateur non connecté.");
      this.router.navigate(['/login']);
      return;
    }

    this.isLoading = true;

    try {
      // Enregistrement dans Firestore : users/{uid}
      await setDoc(doc(db, 'users', user.uid), {
        email: user.email,
        displayName: user.displayName || '',
        role: role,
        createdAt: new Date(),
        // Champs spécifiques selon le rôle
        ...(role === 'worker' ? { specialty: 'Général', rating: 5, completedJobs: 0 } : {})
      }, { merge: true });

      console.log(\`Rôle \${role} enregistré pour \${user.uid}\`);
      
      // Redirection vers le dashboard
      this.router.navigate(['/dashboard']);
      
    } catch (error) {
      console.error("Erreur sauvegarde rôle:", error);
      alert("Impossible d'enregistrer le profil. Vérifiez votre connexion.");
      this.isLoading = false;
    }
  }
}
EOF

# ==========================================
# 2. MISE À JOUR DU DASHBOARD (Vérification Firestore + Gestion Erreur)
# ==========================================
DASHBOARD_DIR="src/app/features/dashboard"
# Création du dossier si inexistant (sécurité)
mkdir -p "$DASHBOARD_DIR"

echo -e "  - Mise à jour DashboardComponent (Fix Blockage)..."

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
  private cdr = inject(ChangeDetectorRef); // IMPORTANT: Pour forcer la mise à jour
  
  userEmail = 'Utilisateur';
  userType: 'client' | 'worker' | 'loading' = 'loading';
  isJobModalOpen = false;

  ngOnInit() {
    // On attend que Firebase confirme l'état de connexion (fiable au refresh)
    onAuthStateChanged(auth, async (user) => {
      if (!user) {
        this.router.navigate(['/login']);
        return;
      }

      this.userEmail = user.email || 'Utilisateur';
      
      // Timeout de sécurité : si Firestore ne répond pas en 5s, on débloque
      const safetyTimeout = setTimeout(() => {
        if (this.userType === 'loading') {
          console.warn("Timeout Firestore. Redirection vers selection.");
          this.router.navigate(['/role-select']);
        }
      }, 5000);

      try {
        const userDoc = await getDoc(doc(db, 'users', user.uid));
        clearTimeout(safetyTimeout);

        if (userDoc.exists() && userDoc.data()['role']) {
          this.userType = userDoc.data()['role'];
          console.log("Rôle chargé:", this.userType);
          
          if (this.router.url === '/dashboard') {
             this.router.navigate(['/dashboard', this.userType]);
          }
        } else {
          console.warn("Pas de rôle, redirection.");
          this.router.navigate(['/role-select']);
        }
        
        // Force l'affichage à se mettre à jour
        this.cdr.detectChanges();

      } catch (error) {
        clearTimeout(safetyTimeout);
        console.error("Erreur Dashboard:", error);
        this.router.navigate(['/role-select']);
      }
    });
  }

  openJobModal() { 
    this.isJobModalOpen = true; 
    this.cdr.detectChanges();
  }
  
  closeJobModal() { 
    this.isJobModalOpen = false; 
    this.cdr.detectChanges();
  }

  async logout() {
    await signOut(auth);
    this.router.navigate(['/']);
  }
}
EOF

# Mise à jour du HTML pour gérer l'état de chargement
cat <<EOF > "$DASHBOARD_DIR/dashboard.component.html"
@if (userType === 'loading') {
  <div class="flex h-screen items-center justify-center bg-gray-50">
    <div class="text-center">
      <div class="animate-spin h-10 w-10 border-4 border-blue-600 border-t-transparent rounded-full mx-auto mb-4"></div>
      <p class="text-gray-500 font-medium">Chargement de votre espace...</p>
      <p class="text-xs text-gray-400 mt-2">Vérification du profil en cours</p>
    </div>
  </div>
} @else {
  <div class="flex flex-col h-screen bg-gray-50 relative">
    
    <!-- HEADER -->
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

    <!-- CONTENT AREA -->
    <main class="flex-grow overflow-y-auto p-4 pb-24">
      <router-outlet></router-outlet>
    </main>

    <!-- POPUP MODAL (Job Request) -->
    @if (isJobModalOpen) {
      <div class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm animate-fade-in">
        <div class="bg-white w-full sm:w-[500px] h-[90%] sm:h-auto sm:max-h-[85vh] rounded-t-3xl sm:rounded-2xl shadow-2xl flex flex-col overflow-hidden animate-slide-up">
          <div class="p-4 border-b flex justify-between items-center bg-gray-50">
            <h3 class="font-bold text-gray-800">Nouvelle Demande</h3>
            <button (click)="closeJobModal()" class="p-2 bg-gray-200 rounded-full hover:bg-gray-300 transition">
              <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path></svg>
            </button>
          </div>
          <div class="flex-grow overflow-y-auto p-2">
            <app-job-request></app-job-request>
          </div>
        </div>
      </div>
    }

    <!-- BOTTOM NAVIGATION -->
    <nav class="fixed bottom-0 left-0 w-full bg-white border-t border-gray-200 px-6 py-3 flex justify-between items-center text-xs font-medium text-gray-500 z-20">
      
      <!-- Accueil -->
      <a [routerLink]="['/dashboard', userType]" routerLinkActive="text-blue-600" class="flex flex-col items-center gap-1">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path></svg>
        <span>Accueil</span>
      </a>

      <!-- Bouton Central (Action) -->
      @if (userType === 'client') {
        <button (click)="openJobModal()" class="flex flex-col items-center justify-center -mt-8 outline-none">
          <div class="w-14 h-14 bg-blue-600 rounded-full shadow-lg shadow-blue-300 flex items-center justify-center text-white transform active:scale-95 transition hover:scale-105">
            <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path></svg>
          </div>
          <span class="mt-1 text-blue-600 font-bold">Demander</span>
        </button>
      } @else {
        <a routerLink="/dashboard/missions" routerLinkActive="text-blue-600" class="flex flex-col items-center gap-1">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"></path></svg>
          <span>Missions</span>
        </a>
      }

      <!-- Recherche -->
      <a routerLink="/pro-search" routerLinkActive="text-blue-600" class="flex flex-col items-center gap-1">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path></svg>
        <span>Trouver</span>
      </a>

    </nav>
  </div>
}
EOF

echo -e "${GREEN}✅ Persistance du Rôle Activée !${NC}"
echo -e "Les nouveaux utilisateurs seront enregistrés dans la collection 'users'."
echo -e "Le Dashboard chargera désormais le rôle depuis la base de données."