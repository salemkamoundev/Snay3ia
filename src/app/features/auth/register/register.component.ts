import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { createUserWithEmailAndPassword, updateProfile } from 'firebase/auth';
import { auth } from '../../../core/firebase.config';

@Component({
  selector: 'app-register',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './register.component.html'
})
export class RegisterComponent {
  private router = inject(Router);
  fullName = ''; email = ''; password = ''; confirmPassword = ''; errorMessage = ''; isLoading = false;
  async onRegister() {
    if (this.password !== this.confirmPassword) { this.errorMessage = 'Les mots de passe ne correspondent pas.'; return; }
    this.isLoading = true; this.errorMessage = '';
    try {
      const userCredential = await createUserWithEmailAndPassword(auth, this.email, this.password);
      if (this.fullName) await updateProfile(userCredential.user, { displayName: this.fullName });
      this.router.navigate(['/role-select']);
    } catch (error: any) { this.errorMessage = error.code; } finally { this.isLoading = false; }
  }
}
