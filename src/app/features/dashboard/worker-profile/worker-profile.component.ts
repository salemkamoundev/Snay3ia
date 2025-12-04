import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { auth, db } from '../../../core/firebase.config'; 
import { collection, query, where, onSnapshot, Unsubscribe, orderBy, limit } from 'firebase/firestore';
import { ChatComponent } from '../chat/chat.component';

interface Job { id: string; description: string; imageUrl?: string; imageUrls?: string[]; status: string; createdAt: any; acceptedPrice?: number; acceptedDuration?: string; acceptedWorkerCount?: number; acceptedDescription?: string; acceptedAt?: any; userEmail?: string; unreadCount?: number; }

@Component({
  selector: 'app-worker-profile',
  standalone: true,
  imports: [CommonModule, ChatComponent],
  template: `
    <div class="space-y-6 pb-20 relative">
      <div class="bg-green-600 rounded-2xl p-6 text-white shadow-lg">
        <h3 class="text-xl font-bold">Espace Artisan</h3>
        <p class="opacity-80">Mes Chantiers Actifs</p>
      </div>
      
      <div>
        @if (!isLoading && activeJobs.length > 0) {
           <div class="space-y-4">
             @for (job of activeJobs; track job.id) {
               <div class="bg-white p-4 rounded-xl shadow-sm border-l-4 border-green-500 flex flex-col gap-2">
                 <div class="flex justify-between items-start">
                   <div>
                     <h5 class="font-bold text-gray-800 line-clamp-1">{{ job.description }}</h5>
                     <span class="text-xs text-gray-500">Demande du : {{ formatTimestamp(job.createdAt) | date:'dd/MM/yyyy' }}</span>
                   </div>
                   @if (job.unreadCount && job.unreadCount > 0) {
                     <span class="bg-red-500 text-white text-xs px-2 py-0.5 rounded-full animate-bounce">{{ job.unreadCount }}</span>
                   }
                 </div>
                 
                 <!-- INFO DEVIS EN AVANT -->
                 <div class="bg-green-50 p-2 rounded border border-green-200 mt-2">
                   <p class="font-bold text-green-800 text-sm">Mon Devis : {{ job.acceptedPrice }} TND</p>
                   <p class="text-xs text-green-700">Validé le : {{ formatTimestamp(job.acceptedAt) | date:'dd/MM/yyyy' }}</p>
                 </div>

                 <div class="flex justify-end items-end mt-2 gap-2">
                     <button (click)="viewJobDetails(job)" class="bg-gray-100 text-gray-700 py-1.5 px-3 rounded-lg text-xs font-bold border border-gray-300">Détails 📋</button>
                     <button (click)="openChat(job)" class="bg-blue-50 text-blue-600 py-1.5 px-3 rounded-lg text-xs font-bold border border-blue-200">Chat 💬</button>
                     <button (click)="contactClient(job)" class="bg-green-50 text-green-700 py-1.5 px-3 rounded-lg text-xs font-bold border border-green-200">Appeler 📞</button>
                 </div>
               </div>
             }
           </div>
        } @else { <div class="text-center py-8 text-gray-500">Aucun chantier actif.</div> }
      </div>

      <!-- Modale Détails -->
      @if (selectedJobForDetails) {
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4 animate-fade-in">
          <div class="bg-white w-full max-w-md rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
            <div class="p-4 border-b flex justify-between items-center bg-gray-50">
              <h3 class="font-bold text-gray-800">Détails du Chantier</h3>
              <button (click)="closeDetails()" class="p-1 bg-gray-200 rounded-full hover:bg-gray-300 transition">✕</button>
            </div>
            
            <div class="flex-grow overflow-y-auto p-4">
              <!-- Galerie -->
              <div class="h-48 w-full bg-black rounded-lg overflow-hidden flex overflow-x-auto snap-x no-scrollbar mb-4">
                @if (getAllMedia(selectedJobForDetails).length > 0) {
                  @for (media of getAllMedia(selectedJobForDetails); track media) {
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

              <div class="space-y-3">
                <div>
                  <label class="text-xs font-bold text-gray-500 uppercase">Description Panne</label>
                  <p class="text-sm text-gray-800 bg-gray-50 p-3 rounded mt-1">{{ selectedJobForDetails.description }}</p>
                </div>

                <!-- DÉTAILS DU DEVIS VALIDÉ -->
                <div class="bg-green-50 p-3 rounded-lg border border-green-200">
                    <h4 class="text-xs font-bold text-green-700 uppercase mb-2">Détails Devis Validé</h4>
                    <div class="grid grid-cols-2 gap-2 text-sm mb-2">
                       <div><span class="font-bold">Prix:</span> {{ selectedJobForDetails.acceptedPrice }} TND</div>
                       <div><span class="font-bold">Durée:</span> {{ selectedJobForDetails.acceptedDuration }}</div>
                       <div><span class="font-bold">Artisans:</span> {{ selectedJobForDetails.acceptedWorkerCount }}</div>
                    </div>
                    <div class="border-t border-green-200 pt-2 mt-2">
                        <label class="text-xs font-bold text-green-700">Message/Description Devis :</label>
                        <p class="text-xs italic text-green-800 mt-1">{{ selectedJobForDetails.acceptedDescription }}</p>
                    </div>
                </div>
                
                <div class="flex justify-between border-t pt-3">
                  <div>
                    <label class="text-xs font-bold text-gray-500 uppercase">Client Email</label>
                    <p class="text-sm font-medium">{{ selectedJobForDetails.userEmail || 'Anonyme' }}</p>
                  </div>
                  <div class="text-right">
                    <label class="text-xs font-bold text-gray-500 uppercase">Dates</label>
                    <p class="text-xs text-gray-600">Créé le: {{ formatTimestamp(selectedJobForDetails.createdAt) | date:'dd/MM/yyyy' }}</p>
                    <p class="text-xs text-green-600 font-bold">Validé le: {{ formatTimestamp(selectedJobForDetails.acceptedAt) | date:'dd/MM/yyyy' }}</p>
                  </div>
                </div>
                
                <div class="pt-2">
                   <button (click)="openChat(selectedJobForDetails); closeDetails()" class="w-full py-3 bg-blue-600 text-white font-bold rounded-xl shadow-md">Ouvrir le Chat</button>
                </div>
              </div>
            </div>
          </div>
        </div>
      }

      <!-- Modale Chat -->
      @if (selectedJobForChat) {
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div class="bg-white w-full max-w-md rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[80vh]">
            <div class="p-3 bg-gray-100 border-b flex justify-between items-center">
              <h3 class="font-bold">Chat Chantier</h3>
              <button (click)="closeChat()" class="text-gray-500 text-xl">×</button>
            </div>
            <app-chat [jobId]="selectedJobForChat.id" class="flex-grow overflow-hidden"></app-chat>
          </div>
        </div>
      }
    </div>
  `
})
export class WorkerProfileComponent implements OnInit, OnDestroy {
  activeJobs: Job[] = []; isLoading = true; selectedJobForChat: Job | null = null; selectedJobForDetails: Job | null = null;
  private unsubscribe: any; private msgListeners: any[] = []; private cdr = inject(ChangeDetectorRef);

  ngOnInit() {
    const user = auth.currentUser; if (!user) return;
    const q = query(collection(db, 'jobs'), where('workerId', '==', user.uid), where('status', '==', 'assigned'));
    this.unsubscribe = onSnapshot(q, (s) => {
      this.activeJobs = s.docs.map((d: any) => ({id: d.id, ...d.data()})) as Job[]; 
      this.isLoading = false; this.listenToMessages(); this.cdr.detectChanges();
    });
  }
  listenToMessages() {
    this.msgListeners.forEach(u => u()); this.msgListeners = [];
    this.activeJobs.forEach(job => {
      this.msgListeners.push(onSnapshot(query(collection(db, 'jobs', job.id, 'messages'), orderBy('createdAt', 'desc'), limit(10)), (s) => {
        const msgs = s.docs.map(d => d.data());
        job.unreadCount = msgs.filter((m: any) => !m.read && m.senderId !== auth.currentUser?.uid).length;
        this.cdr.detectChanges();
      }));
    });
  }
  
  viewJobDetails(job: Job) { this.selectedJobForDetails = job; }
  closeDetails() { this.selectedJobForDetails = null; }
  openChat(job: Job) { this.selectedJobForChat = job; }
  closeChat() { this.selectedJobForChat = null; }
  
  contactClient(job: Job) { if(job.userEmail) window.location.href = `mailto:${job.userEmail}`; }
  
  getAllMedia(job: Job): string[] { if (job.imageUrls && job.imageUrls.length > 0) return job.imageUrls; if (job.imageUrl) return [job.imageUrl]; return []; }
  isVideo(url: string): boolean { if (!url) return false; return !!url.match(/\.(mp4|webm|ogg|mov|avi|mkv)(\?.*)?$/i); }
  
  formatTimestamp(t: any) { return t?.toDate ? t.toDate() : new Date(t || new Date()); }
  ngOnDestroy() { if(this.unsubscribe) this.unsubscribe(); this.msgListeners.forEach(u => u()); }
}
