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
