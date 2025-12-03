import { Component } from '@angular/core';
import { CommonModule } from '@angular/common';

@Component({
  selector: 'app-worker-profile',
  standalone: true,
  imports: [CommonModule],
  template: `
    <div class="space-y-6">
      <div class="bg-green-600 rounded-2xl p-6 text-white shadow-lg">
        <h3 class="text-xl font-bold">Espace Artisan</h3>
        <p class="opacity-80">Gérez vos chantiers et clients</p>
      </div>
      
      <div class="grid grid-cols-2 gap-4">
        <div class="bg-white p-4 rounded-xl shadow-sm border text-center">
          <span class="block text-2xl font-bold text-green-600">0</span>
          <span class="text-xs text-gray-500">Missions actives</span>
        </div>
        <div class="bg-white p-4 rounded-xl shadow-sm border text-center">
          <span class="block text-2xl font-bold text-blue-600">0 TND</span>
          <span class="text-xs text-gray-500">Gains ce mois</span>
        </div>
      </div>
    </div>
  `
})
export class WorkerProfileComponent {}
