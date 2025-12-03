import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { auth, db } from '../../../core/firebase.config'; // CORRECTION PATH
import { collection, query, where, onSnapshot, Unsubscribe, updateDoc, doc } from 'firebase/firestore';
import { UserService, WorkerProfile } from '../../../core/services/user.service'; // CORRECTION PATH

interface Proposal {
  workerId: string;
  workerName: string;
  price: number;
  status: string;
}

interface Job {
  id: string;
  description: string;
  imageUrl?: string;
  imageUrls?: string[];
  status: string;
  createdAt: any;
  proposals?: Proposal[];
}

@Component({
  selector: 'app-user-profile',
  standalone: true,
  imports: [CommonModule, DatePipe],
  template: `
    <div class="space-y-6 pb-20 relative">
      <div class="bg-blue-600 rounded-2xl p-6 text-white shadow-lg relative overflow-hidden">
        <div class="relative z-10">
          <h3 class="text-2xl font-bold">Mes Pannes</h3>
          <p class="opacity-90 text-blue-100">Gérez vos demandes et les artisans.</p>
        </div>
        <div class="absolute right-[-20px] top-[-20px] w-32 h-32 bg-white opacity-10 rounded-full blur-2xl"></div>
      </div>

      @if (!isLoading && jobs.length > 0) {
        <div class="space-y-6">
          @for (job of jobs; track job.id) {
            <div class="bg-white p-4 rounded-xl shadow-sm border border-gray-100">
              
              <!-- Info Job -->
              <div class="flex gap-4 items-start mb-4">
                <div class="w-20 h-20 flex-shrink-0 bg-gray-100 rounded-lg overflow-hidden border border-gray-200 relative">
                  @if (isVideo(getMainMedia(job))) {
                     <div class="w-full h-full bg-black flex items-center justify-center"><span class="text-2xl">▶️</span></div>
                  } @else {
                     <img [src]="getMainMedia(job)" alt="Panne" class="w-full h-full object-cover">
                  }
                </div>
                <div class="flex-grow min-w-0">
                  <div class="flex justify-between items-start mb-1">
                    <span [class]="getStatusClass(job.status)" class="px-2 py-0.5 rounded-md text-[10px] font-bold uppercase tracking-wider">
                      {{ getStatusLabel(job.status) }}
                    </span>
                    <span class="text-xs text-gray-400 ml-2">{{ formatTimestamp(job.createdAt) | date:'dd MMM' }}</span>
                  </div>
                  <p class="text-gray-800 font-medium text-sm line-clamp-2">{{ job.description }}</p>
                </div>
              </div>

              <!-- SECTION PROPOSITIONS (Si statut 'analyzing') -->
              @if (job.status === 'analyzing' && job.proposals && job.proposals.length > 0) {
                <div class="border-t border-gray-100 pt-3">
                  <h5 class="text-sm font-bold text-gray-700 mb-3 flex items-center">
                    <span class="bg-red-100 text-red-600 rounded-full w-5 h-5 flex items-center justify-center text-xs mr-2">{{ job.proposals.length }}</span>
                    Artisans intéressés
                  </h5>
                  
                  <div class="space-y-3">
                    @for (proposal of job.proposals; track proposal.workerId) {
                      <div class="bg-gray-50 p-3 rounded-lg flex justify-between items-center">
                        <div (click)="viewWorkerProfile(proposal.workerId)" class="cursor-pointer">
                          <p class="font-bold text-gray-800 text-sm hover:underline">{{ proposal.workerName }}</p>
                          <p class="text-green-600 font-bold text-sm">{{ proposal.price }} TND</p>
                        </div>
                        <div class="flex gap-2">
                          <button (click)="viewWorkerProfile(proposal.workerId)" class="text-xs bg-white border border-gray-300 text-gray-600 px-3 py-1.5 rounded-md">Profil</button>
                          <button (click)="acceptProposal(job, proposal)" class="text-xs bg-green-600 text-white px-3 py-1.5 rounded-md font-bold shadow-sm">Accepter</button>
                        </div>
                      </div>
                    }
                  </div>
                </div>
              }
              
              <!-- Feedback si attente -->
              @if (job.status === 'analyzing' && (!job.proposals || job.proposals.length === 0)) {
                <div class="bg-yellow-50 text-yellow-800 text-xs p-2 rounded text-center">
                  En attente de propositions d'artisans...
                </div>
              }
            </div>
          }
        </div>
      }

      <!-- MODALE PROFIL ARTISAN -->
      @if (selectedWorker) {
        <div class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm animate-fade-in">
          <div class="bg-white w-full sm:w-[400px] rounded-t-3xl sm:rounded-2xl shadow-2xl overflow-hidden animate-slide-up">
            <div class="bg-blue-600 p-6 text-white text-center relative">
              <button (click)="closeProfile()" class="absolute top-4 right-4 text-white/80 hover:text-white">✕</button>
              <div class="w-20 h-20 bg-white text-blue-600 rounded-full mx-auto flex items-center justify-center text-3xl font-bold mb-3 shadow-md">
                {{ selectedWorker.displayName.charAt(0) }}
              </div>
              <h2 class="text-xl font-bold">{{ selectedWorker.displayName }}</h2>
              <p class="text-blue-100 text-sm">{{ selectedWorker.specialty }}</p>
              <div class="flex justify-center gap-1 mt-2 text-yellow-300">
                <span>★</span><span>{{ selectedWorker.rating }}</span> <span class="text-white/60 text-xs">({{ selectedWorker.reviews.length }} avis)</span>
              </div>
            </div>
            
            <div class="p-6 max-h-[50vh] overflow-y-auto">
              <h3 class="font-bold text-gray-800 mb-3">Derniers avis clients</h3>
              <div class="space-y-4">
                @for (review of selectedWorker.reviews; track review.author) {
                  <div class="border-b border-gray-100 pb-3 last:border-0">
                    <div class="flex justify-between items-center mb-1">
                      <span class="font-bold text-sm text-gray-700">{{ review.author }}</span>
                      <span class="text-yellow-500 text-xs">★ {{ review.rating }}</span>
                    </div>
                    <p class="text-gray-500 text-xs italic">"{{ review.comment }}"</p>
                  </div>
                }
              </div>
            </div>
            
            <div class="p-4 border-t border-gray-100 bg-gray-50 text-center">
              <button (click)="closeProfile()" class="text-gray-500 font-medium text-sm">Fermer</button>
            </div>
          </div>
        </div>
      }
    </div>
  `
})
export class UserProfileComponent implements OnInit, OnDestroy {
  jobs: Job[] = [];
  isLoading = true;
  selectedWorker: WorkerProfile | null = null;
  
  private unsubscribe: Unsubscribe | null = null;
  private cdr = inject(ChangeDetectorRef);
  private userService = inject(UserService);

  ngOnInit() {
    const user = auth.currentUser;
    if (!user) return;

    const jobsQuery = query(collection(db, 'jobs'), where('userId', '==', user.uid));

    this.unsubscribe = onSnapshot(jobsQuery, (snapshot) => {
      const fetchedJobs = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })) as Job[];
      this.jobs = fetchedJobs.sort((a, b) => this.formatTimestamp(b.createdAt).getTime() - this.formatTimestamp(a.createdAt).getTime());
      this.isLoading = false;
      this.cdr.detectChanges();
    });
  }

  // Affiche la modale
  viewWorkerProfile(workerId: string) {
    this.userService.getWorkerProfile(workerId).subscribe(profile => {
      this.selectedWorker = profile;
      this.cdr.detectChanges();
    });
  }

  closeProfile() {
    this.selectedWorker = null;
    this.cdr.detectChanges();
  }

  async acceptProposal(job: Job, proposal: Proposal) {
    if(!confirm(`Accepter le devis de ${proposal.workerName} pour ${proposal.price} TND ?`)) return;

    try {
      await updateDoc(doc(db, 'jobs', job.id), {
        status: 'assigned',
        workerId: proposal.workerId,
        acceptedPrice: proposal.price,
        acceptedAt: new Date()
      });
      alert("Artisan validé ! Il sera notifié.");
    } catch (e) {
      console.error(e);
      alert("Erreur lors de la validation.");
    }
  }

  // --- Helpers ---
  getMainMedia(job: Job): string {
    if (job.imageUrls && job.imageUrls.length > 0) return job.imageUrls[0];
    return job.imageUrl || '';
  }

  isVideo(url: string): boolean {
    if (!url) return false;
    return !!url.match(/\.(mp4|webm|ogg|mov|avi|mkv)(\?.*)?$/i);
  }

  getStatusLabel(status: string): string {
    const labels: any = { 'analyzing': 'En cours', 'assigned': 'Confirmé', 'completed': 'Terminé' };
    return labels[status] || status;
  }

  getStatusClass(status: string): string {
    return status === 'assigned' ? 'bg-green-100 text-green-700' : 'bg-blue-100 text-blue-700';
  }

  formatTimestamp(timestamp: any): Date {
    if (timestamp && typeof timestamp.toDate === 'function') return timestamp.toDate();
    return timestamp ? new Date(timestamp) : new Date();
  }

  ngOnDestroy() { if (this.unsubscribe) this.unsubscribe(); }
}
