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
