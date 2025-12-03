import { Component, inject, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterOutlet, RouterLink, RouterLinkActive, Router } from '@angular/router';
import { auth } from '../../core/firebase.config';
import { signOut } from 'firebase/auth';
// Import du composant JobRequest pour le Popup
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
  userEmail = auth.currentUser?.email || 'Utilisateur';
  
  userType: 'client' | 'worker' = 'client';
  
  // État du Popup
  isJobModalOpen = false;

  ngOnInit() {
    // Récupération du rôle depuis le stockage local
    const storedRole = localStorage.getItem('snay3ia_role');
    
    if (storedRole === 'client' || storedRole === 'worker') {
      this.userType = storedRole;
    } else {
      // Si aucun rôle n'est défini, on redirige vers la sélection
      this.router.navigate(['/role-select']);
    }
  }

  openJobModal() {
    this.isJobModalOpen = true;
  }

  closeJobModal() {
    this.isJobModalOpen = false;
  }

  async logout() {
    await signOut(auth);
    localStorage.removeItem('snay3ia_role'); // On nettoie le rôle à la déconnexion
    this.router.navigate(['/']);
  }
}
