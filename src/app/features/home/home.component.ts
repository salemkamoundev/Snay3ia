import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router, RouterLink } from '@angular/router';
import { GoogleAuthProvider, signInWithPopup } from 'firebase/auth';
import { auth } from '../../core/firebase.config'; // Import de la config Firebase

@Component({
  selector: 'app-home',
  standalone: true,
  imports: [CommonModule, RouterLink],
  templateUrl: './home.component.html',
  styleUrl: './home.component.scss'
})
export class HomeComponent {
  private router = inject(Router);

  features = [
    {
      title: '1. Photographiez',
      desc: 'Prenez une photo de votre panne.',
      icon: '📸',
      color: 'bg-blue-100 text-blue-600'
    },
    {
      title: '2. Analysez (IA)',
      desc: 'Notre IA diagnostique et estime le prix.',
      icon: '🤖',
      color: 'bg-yellow-100 text-yellow-600'
    },
    {
      title: '3. Reparez',
      desc: 'Trouvez un artisan fiable à proximité.',
      icon: '🛠️',
      color: 'bg-green-100 text-green-600'
    }
  ];

  /**
   * Gère la connexion avec Google via Firebase Popup.
   */
  async loginWithGoogle() {
    console.log('Tentative de connexion Google...');
    try {
      const provider = new GoogleAuthProvider();
      const result = await signInWithPopup(auth, provider);
      
      // Informations de l'utilisateur connecté
      const user = result.user;
      console.log('Connexion réussie pour :', user.displayName);

      // Redirection vers la page de demande de job après connexion
      // Vous pouvez changer cette route vers '/pro-search' selon le flux souhaité
      await this.router.navigate(['/dashboard']);
      
    } catch (error: any) {
      console.error('Erreur lors de la connexion Google:', error);
      // Gestion basique des erreurs (à améliorer avec un Toast/Notification UI)
      alert(`Erreur de connexion : ${error.message}`);
    }
  }
}
