import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { signInWithEmailAndPassword } from 'firebase/auth';
import { auth } from '../../../core/firebase.config';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './login.component.html'
})
export class LoginComponent {
  private router = inject(Router);
  
  email = '';
  password = '';
  errorMessage = ''; // Variable pour afficher le message d'erreur
  isLoading = false;

  async onLogin() {
    this.isLoading = true;
    this.errorMessage = ''; // Réinitialiser le message à chaque tentative
    
    try {
      await signInWithEmailAndPassword(auth, this.email, this.password);
      // Succès: Redirection vers le dashboard qui gère la sélection de rôle
      this.router.navigate(['/dashboard']);
    } catch (error: any) {
      console.error('Login error', error);
      
      // Mise à jour de la variable errorMessage en fonction du code Firebase
      switch(error.code) {
        case 'auth/invalid-credential':
        case 'auth/user-not-found': // Souvent groupé avec invalid-credential pour ne pas donner d'indice
        case 'auth/wrong-password':
          this.errorMessage = 'Email ou mot de passe incorrect. Veuillez réessayer.';
          break;
        case 'auth/invalid-email':
          this.errorMessage = 'Format d\'adresse email invalide.';
          break;
        default:
          this.errorMessage = 'Une erreur de connexion est survenue. Code: ' + error.code;
      }
    } finally {
      this.isLoading = false;
    }
  }
}
