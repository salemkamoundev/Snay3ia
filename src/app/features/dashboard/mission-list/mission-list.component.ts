import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { auth, db } from '../../../core/firebase.config'; // CORRECTION PATH
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
  template: `
    <div class="space-y-6 pb-24">
      <div class="bg-green-600 rounded-2xl p-6 text-white shadow-lg relative overflow-hidden">
        <div class="relative z-10">
          <h3 class="text-2xl font-bold">Missions</h3>
          <p class="opacity-90 text-green-100">Postulez aux chantiers disponibles</p>
        </div>
        <div class="absolute right-[-20px] top-[-20px] w-32 h-32 bg-white opacity-10 rounded-full blur-2xl"></div>
      </div>

      <!-- MESSAGE D'ERREUR (DEBUG) -->
      @if (errorMessage) {
        <div class="bg-red-100 border-l-4 border-red-500 text-red-700 p-4 rounded shadow-md" role="alert">
          <p class="font-bold">Erreur de chargement</p>
          <p>{{ errorMessage }}</p>
          <p class="text-xs mt-2">Vérifiez vos règles Firestore dans la console Firebase.</p>
        </div>
      }

      @if (isLoading) {
        <div class="flex justify-center py-10">
          <div class="animate-spin h-8 w-8 border-4 border-green-500 border-t-transparent rounded-full"></div>
        </div>
      }

      @if (!isLoading && !errorMessage && jobs.length > 0) {
        <div class="space-y-4">
          @for (job of jobs; track job.id) {
            <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
              
              <!-- Galerie -->
              <div class="h-48 w-full bg-black flex overflow-x-auto snap-x no-scrollbar">
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
                     {{ job.proposals?.length || 0 }} candidature(s)
                   </span>
                </div>
                <p class="text-gray-800 text-sm mb-4">{{ job.description }}</p>
                
                @if (hasApplied(job)) {
                  <button disabled class="w-full py-3 bg-gray-300 text-gray-600 font-bold rounded-lg cursor-not-allowed">
                    Déjà postulé ✅
                  </button>
                } @else {
                  <div class="bg-gray-50 p-3 rounded-lg border border-gray-200 mb-3">
                    <label class="text-xs font-bold text-gray-500 block mb-1">Votre offre (TND)</label>
                    <div class="flex gap-2">
                      <input type="number" [(ngModel)]="offerPrice[job.id]" placeholder="Prix" class="w-1/2 p-2 rounded border border-gray-300 text-sm">
                      <button (click)="applyToJob(job)" class="w-1/2 py-2 bg-green-600 text-white font-bold rounded hover:bg-green-700 text-sm">
                        Envoyer
                      </button>
                    </div>
                  </div>
                }
              </div>
            </div>
          }
        </div>
      } @else if (!isLoading && !errorMessage) {
        <div class="text-center py-10 text-gray-500">
          <div class="text-4xl mb-2">📭</div>
          Aucune mission disponible avec le statut "En cours".
        </div>
      }
    </div>
  `
})
export class MissionListComponent implements OnInit, OnDestroy {
  jobs: Job[] = [];
  isLoading = true;
  errorMessage = ''; // Pour afficher les erreurs de permission
  offerPrice: { [key: string]: number } = {};
  
  private unsubscribe: Unsubscribe | null = null;
  private cdr = inject(ChangeDetectorRef);
  private currentUser = auth.currentUser;

  ngOnInit() {
    // Requête : On cherche les jobs qui attendent des propositions ('analyzing')
    const jobsQuery = query(collection(db, 'jobs'), where('status', '==', 'analyzing'));
    
    this.unsubscribe = onSnapshot(jobsQuery, (snapshot) => {
      console.log('[MissionList] Snapshot reçu. Docs:', snapshot.docs.length);
      
      const fetchedJobs = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as Job[];
      
      this.jobs = fetchedJobs.sort((a, b) => this.formatTimestamp(b.createdAt).getTime() - this.formatTimestamp(a.createdAt).getTime());
      this.isLoading = false;
      this.errorMessage = ''; // Clear error on success
      this.cdr.detectChanges();
    }, (error) => {
      console.error("[MissionList] Erreur Firestore:", error);
      this.errorMessage = error.message; // Affiche l'erreur à l'utilisateur
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
      alert("Candidature envoyée !");
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
