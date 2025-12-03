import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';

@Component({
  selector: 'app-role-selection',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="min-h-screen bg-gradient-to-br from-blue-600 to-blue-800 flex flex-col items-center justify-center p-6 text-white">
      <h1 class="text-3xl font-bold mb-2">Bienvenue sur Snay3ia</h1>
      <p class="text-blue-100 mb-10 text-center">Pour commencer, dites-nous qui vous êtes.</p>

      <div class="grid gap-6 w-full max-w-md">
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
    </div>
  `
})
export class RoleSelectionComponent {
  private router = inject(Router);

  selectRole(role: 'client' | 'worker') {
    localStorage.setItem('snay3ia_role', role);
    this.router.navigate(['/dashboard', role]);
  }
}
