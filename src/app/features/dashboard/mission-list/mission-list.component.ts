import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { auth, db } from '../../../core/firebase.config';
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
          <p class="opacity-90 text-green-100">Proposez vos services aux clients.</p>
        </div>
        <div class="absolute right-[-20px] top-[-20px] w-32 h-32 bg-white opacity-10 rounded-full blur-2xl"></div>
      </div>

      @if (!isLoading && jobs.length > 0) {
        <div class="space-y-4">
          @for (job of jobs; track job.id) {
            <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
              
              <!-- Galerie Photo/Vidéo -->
              <div class="h-64 w-full bg-black flex overflow-x-auto snap-x no-scrollbar">
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
                     {{ job.proposals?.length || 0 }} devis envoyés
                   </span>
                </div>
                
                <h4 class="font-bold text-gray-800 mb-1">Description du problème :</h4>
                <p class="text-gray-600 text-sm mb-4 bg-gray-50 p-3 rounded-lg">{{ job.description }}</p>
                
                @if (hasApplied(job)) {
                  <div class="bg-green-50 text-green-700 p-3 rounded-lg text-center font-bold text-sm border border-green-200">
                    ✅ Vous avez envoyé une proposition
                  </div>
                } @else {
                  <div class="border-t border-gray-100 pt-4">
                    <label class="text-xs font-bold text-gray-500 block mb-2">Envoyer un devis estimatif :</label>
                    <div class="flex gap-2">
                      <div class="relative flex-grow">
                        <input type="number" [(ngModel)]="offerPrice[job.id]" placeholder="0" class="w-full pl-3 pr-8 py-2 rounded-lg border border-gray-300 focus:ring-2 focus:ring-green-500 outline-none transition">
                        <span class="absolute right-3 top-2 text-gray-400 text-sm">TND</span>
                      </div>
                      <button (click)="applyToJob(job)" class="bg-green-600 text-white font-bold py-2 px-4 rounded-lg hover:bg-green-700 shadow-sm transition">
                        Envoyer
                      </button>
                    </div>
                  </div>
                }
              </div>
            </div>
          }
        </div>
      } @else if (!isLoading) {
        <div class="text-center py-10 text-gray-500">
          <div class="text-4xl mb-2">📭</div>
          Aucune mission disponible pour le moment.
        </div>
      }
    </div>
  `
})
export class MissionListComponent implements OnInit, OnDestroy {
  jobs: Job[] = [];
  isLoading = true;
  offerPrice: { [key: string]: number } = {};
  
  private unsubscribe: Unsubscribe | null = null;
  private cdr = inject(ChangeDetectorRef);
  private currentUser = auth.currentUser;

  ngOnInit() {
    const jobsQuery = query(collection(db, 'jobs'), where('status', '==', 'analyzing'));
    
    this.unsubscribe = onSnapshot(jobsQuery, (snapshot) => {
      const fetchedJobs = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as Job[];
      this.jobs = fetchedJobs.sort((a, b) => this.formatTimestamp(b.createdAt).getTime() - this.formatTimestamp(a.createdAt).getTime());
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
      
      alert("Proposition envoyée au client !");
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
