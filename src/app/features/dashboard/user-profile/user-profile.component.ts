import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { auth, db } from '../../../core/firebase.config'; 
import { collection, query, where, onSnapshot, Unsubscribe, updateDoc, doc, addDoc, orderBy, limit } from 'firebase/firestore';
import { UserService, WorkerProfile } from '../../../core/services/user.service';
import { ChatComponent } from '../chat/chat.component';

interface Proposal { workerId: string; workerName: string; price: number; duration: string; workerCount: number; description: string; audioUrl?: string; status: string; }
interface Job { id: string; description: string; imageUrl?: string; imageUrls?: string[]; status: string; createdAt: any; proposals?: Proposal[]; unreadCount?: number; }
interface Notification { id: string; message: string; createdAt: any; read: boolean; }

@Component({
  selector: 'app-user-profile',
  standalone: true,
  imports: [CommonModule, ChatComponent],
  template: `
    <div class="space-y-6 pb-20 relative">
      <!-- HEADER CLIENT -->
      <div class="bg-blue-600 rounded-2xl p-6 text-white shadow-lg relative overflow-hidden flex justify-between items-start">
        <div class="relative z-10">
          <h3 class="text-2xl font-bold">Mes Pannes</h3>
          <p class="opacity-90 text-blue-100">Gérez vos demandes</p>
        </div>
        
        <!-- Notifications Bell -->
        <button (click)="toggleNotifications()" class="relative z-10 p-2 bg-white/20 backdrop-blur rounded-full hover:bg-white/30 transition">
          <span class="text-2xl">🔔</span>
          @if (unreadCount > 0) { <span class="absolute top-0 right-0 h-4 w-4 bg-red-500 rounded-full text-[10px] flex items-center justify-center font-bold border-2 border-blue-600">{{ unreadCount }}</span> }
        </button>
        <div class="absolute right-[-20px] top-[-20px] w-32 h-32 bg-white opacity-10 rounded-full blur-2xl"></div>
      </div>

      <!-- PANNEAU NOTIFICATIONS -->
      @if (showNotifications) {
        <div class="bg-white rounded-xl shadow-xl border border-gray-100 overflow-hidden mb-4 animate-slide-in">
          <div class="p-3 border-b bg-gray-50 flex justify-between items-center"><h4 class="font-bold text-gray-700 text-sm">Notifications</h4></div>
          <div class="max-h-60 overflow-y-auto">
            @if (notifications.length > 0) {
              @for (notif of notifications; track notif.id) {
                <div class="p-3 border-b last:border-0 hover:bg-gray-50 transition" [class.bg-blue-50]="!notif.read">
                  <p class="text-sm text-gray-800" [class.font-bold]="!notif.read">{{ notif.message }}</p>
                  <span class="text-[10px] text-gray-400">{{ formatTimestamp(notif.createdAt) | date:'short' }}</span>
                </div>
              }
            } @else { <div class="p-6 text-center text-gray-400 text-sm">Aucune notification.</div> }
          </div>
        </div>
      }

      @if (!isLoading && jobs.length > 0) {
        <div class="space-y-4">
          @for (job of jobs; track job.id) {
            <div class="bg-white p-4 rounded-xl shadow-sm border border-gray-100 flex flex-col gap-3">
              
              <!-- INFO JOB CARD -->
              <div class="flex gap-4 items-start">
                <div class="w-20 h-20 flex-shrink-0 bg-gray-100 rounded-lg overflow-hidden relative">
                  <img [src]="getMainMedia(job)" class="w-full h-full object-cover">
                  @if (job.imageUrls && job.imageUrls.length > 1) {
                    <div class="absolute bottom-0 right-0 bg-black/50 text-white text-[10px] px-1 rounded-tl">+{{ job.imageUrls.length - 1 }}</div>
                  }
                </div>
                <div class="flex-grow min-w-0">
                  <div class="flex justify-between items-start mb-1">
                    <span class="px-2 py-0.5 rounded text-[10px] font-bold uppercase" [class]="getStatusClass(job.status)">{{ getStatusLabel(job.status) }}</span>
                    <span class="text-xs text-gray-400 ml-2">{{ formatTimestamp(job.createdAt) | date:'dd MMM' }}</span>
                  </div>
                  <p class="text-gray-800 font-medium text-sm line-clamp-2">{{ job.description }}</p>
                  
                  <!-- Badge Propositions -->
                  @if (job.status === 'analyzing' && job.proposals?.length) {
                    <span class="inline-block mt-2 text-xs bg-blue-100 text-blue-800 px-2 py-0.5 rounded-full font-bold">
                      {{ job.proposals?.length }} Proposition(s) reçue(s) <!-- CORRECTION: ?.length -->
                    </span>
                  }
                </div>
              </div>

              <!-- ACTIONS -->
              <div class="flex gap-2 border-t pt-3">
                <button (click)="viewDetails(job)" class="flex-1 py-2 bg-gray-100 text-gray-700 rounded-lg text-sm font-bold border border-gray-300">Détails 📋</button>
                @if (job.status === 'assigned' || job.status === 'analyzing') {
                  <button (click)="openChat(job)" class="flex-1 py-2 bg-blue-50 text-blue-600 rounded-lg text-sm font-bold border border-blue-200">
                    Chat 💬 @if(job.unreadCount){<span class="text-red-500">•</span>}
                  </button>
                }
              </div>
            </div>
          }
        </div>
      } @else { <div class="text-center py-10 text-gray-500">Aucune demande en cours.</div> }

      <!-- MODALE DÉTAILS -->
      @if (selectedJobDetails) {
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4 animate-fade-in">
          <div class="bg-white w-full max-w-md rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
            <div class="p-4 border-b flex justify-between items-center bg-gray-50">
              <h3 class="font-bold text-gray-800">Détails de la demande</h3>
              <button (click)="closeDetails()" class="p-1 bg-gray-200 rounded-full hover:bg-gray-300 transition">✕</button>
            </div>
            
            <div class="flex-grow overflow-y-auto p-4">
              <!-- Galerie -->
              <div class="h-48 w-full bg-black rounded-lg overflow-hidden flex overflow-x-auto snap-x no-scrollbar mb-4">
                @if (getAllMedia(selectedJobDetails).length > 0) {
                  @for (media of getAllMedia(selectedJobDetails); track media) {
                    <div class="w-full h-full flex-shrink-0 snap-center relative flex items-center justify-center bg-gray-900">
                      @if (isVideo(media)) {
                        <video [src]="media" controls class="max-w-full max-h-full"></video>
                      } @else {
                        <img [src]="media" class="w-full h-full object-cover">
                      }
                    </div>
                  }
                }
              </div>

              <div class="space-y-4">
                <div>
                  <h4 class="text-xs font-bold text-gray-500 uppercase">Description</h4>
                  <p class="text-sm text-gray-800 bg-gray-50 p-3 rounded mt-1">{{ selectedJobDetails.description }}</p>
                </div>

                <!-- LISTE DES PROPOSITIONS DANS LA MODALE -->
                @if (selectedJobDetails.status === 'analyzing' && selectedJobDetails.proposals) {
                  <div>
                    <h4 class="text-xs font-bold text-gray-500 uppercase mb-2">Propositions des artisans</h4>
                    <div class="space-y-3">
                      @for (prop of selectedJobDetails.proposals; track prop.workerId) {
                        <div class="border rounded-lg p-3 bg-blue-50/50">
                          <div class="flex justify-between items-start">
                            <div>
                              <p class="font-bold text-gray-800">{{ prop.workerName }}</p>
                              <div class="text-xs text-gray-500 flex gap-2 mt-1">
                                <span class="bg-white px-1 rounded border">⏱️ {{ prop.duration }}</span>
                                <span class="bg-white px-1 rounded border">👷 x{{ prop.workerCount }}</span>
                              </div>
                            </div>
                            <span class="text-green-600 font-bold text-lg">{{ prop.price }} TND</span>
                          </div>
                          
                          @if (prop.description) { <p class="text-xs text-gray-600 italic mt-2">"{{ prop.description }}"</p> }
                          
                          <div class="mt-3 flex gap-2">
                            <button (click)="viewWorkerProfile(prop.workerId)" class="flex-1 text-xs bg-white border border-gray-300 text-gray-600 py-2 rounded font-medium">Voir Profil</button>
                            <button (click)="acceptProposal(selectedJobDetails, prop)" class="flex-1 text-xs bg-green-600 text-white py-2 rounded font-bold shadow-sm">Accepter</button>
                          </div>
                        </div>
                      }
                    </div>
                  </div>
                }
              </div>
            </div>
          </div>
        </div>
      }

      <!-- MODALE CHAT -->
      @if (selectedJobForChat) {
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div class="bg-white w-full max-w-md rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[80vh]">
            <div class="p-3 bg-gray-100 border-b flex justify-between items-center">
              <h3 class="font-bold">Chat</h3>
              <button (click)="closeChat()" class="text-gray-500 text-xl">×</button>
            </div>
            <app-chat [jobId]="selectedJobForChat.id" class="flex-grow overflow-hidden"></app-chat>
          </div>
        </div>
      }

      <!-- MODALE PROFIL ARTISAN (Simplifiée) -->
      @if (selectedWorker) {
        <div class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm animate-fade-in p-4">
          <div class="bg-white w-full max-w-md rounded-2xl shadow-2xl overflow-hidden">
            <div class="bg-blue-600 p-6 text-white text-center relative">
              <button (click)="closeProfile()" class="absolute top-4 right-4 text-white">✕</button>
              <h2 class="text-xl font-bold">{{ selectedWorker.displayName }}</h2>
              <p class="text-blue-100 text-sm">{{ selectedWorker.specialty }}</p>
              <div class="flex justify-center gap-1 mt-2 text-yellow-300">★ {{ selectedWorker.rating }}</div>
            </div>
            <div class="p-6 text-center">
              <p class="text-gray-600 text-sm mb-4">Cet artisan a réalisé {{ selectedWorker.completedJobs }} chantiers.</p>
              <button (click)="closeProfile()" class="text-blue-600 font-bold underline">Fermer</button>
            </div>
          </div>
        </div>
      }
    </div>
  `
})
export class UserProfileComponent implements OnInit, OnDestroy {
  jobs: Job[] = []; notifications: Notification[] = []; isLoading = true; 
  selectedJobForChat: Job | null = null; selectedJobDetails: Job | null = null; selectedWorker: WorkerProfile | null = null;
  showNotifications = false; unreadCount = 0;
  
  private unsubscribe: any; private notifUnsubscribe: any; private cdr = inject(ChangeDetectorRef); private userService = inject(UserService); currentUser = auth.currentUser;

  ngOnInit() {
    if (!this.currentUser) return;
    
    // Jobs Listener
    this.unsubscribe = onSnapshot(query(collection(db, 'jobs'), where('userId', '==', this.currentUser.uid)), (s) => {
      this.jobs = s.docs.map(d => ({id: d.id, ...d.data()})) as Job[]; 
      this.jobs.sort((a, b) => this.formatTimestamp(b.createdAt).getTime() - this.formatTimestamp(a.createdAt).getTime());
      this.isLoading = false; 
      this.cdr.detectChanges();
    });

    // Notifications Listener
    this.notifUnsubscribe = onSnapshot(query(collection(db, 'users', this.currentUser.uid, 'notifications'), orderBy('createdAt', 'desc'), limit(20)), (s) => {
      this.notifications = s.docs.map(d => ({id: d.id, ...d.data()})) as Notification[];
      this.unreadCount = this.notifications.filter(n => !n.read).length;
      this.cdr.detectChanges();
    });
  }

  toggleNotifications() { this.showNotifications = !this.showNotifications; if(this.showNotifications) this.markAsRead(); }
  markAsRead() { this.notifications.forEach(n => { if(!n.read) updateDoc(doc(db, 'users', this.currentUser!.uid, 'notifications', n.id), {read: true}); }); }

  viewDetails(job: Job) { this.selectedJobDetails = job; }
  closeDetails() { this.selectedJobDetails = null; }
  
  openChat(job: Job) { this.selectedJobForChat = job; }
  closeChat() { this.selectedJobForChat = null; }

  viewWorkerProfile(workerId: string) {
    this.userService.getWorkerProfile(workerId).subscribe(p => { this.selectedWorker = p; this.cdr.detectChanges(); });
  }
  closeProfile() { this.selectedWorker = null; }

  async acceptProposal(job: Job, proposal: Proposal) {
    if(!confirm('Valider cet artisan ?')) return;
    try {
      await updateDoc(doc(db, 'jobs', job.id), { status: 'assigned', workerId: proposal.workerId, acceptedPrice: proposal.price });
      // Notif Artisan
      await addDoc(collection(db, 'users', proposal.workerId, 'notifications'), {
        message: 'Votre devis a été accepté !', createdAt: new Date().toISOString(), read: false
      });
      alert("Validé !");
      this.closeDetails();
    } catch (e) { alert("Erreur"); }
  }

  getMainMedia(j: Job) { return j.imageUrls?.[0] || j.imageUrl || ''; }
  getAllMedia(j: Job) { return j.imageUrls || [j.imageUrl || '']; }
  isVideo(u: string) { return !!u.match(/\.(mp4|webm)(\?.*)?$/i); }
  getStatusLabel(s: string) { return s === 'assigned' ? 'En Cours' : 'Ouvert'; }
  getStatusClass(s: string) { return s === 'assigned' ? 'bg-green-100 text-green-700' : 'bg-blue-100 text-blue-700'; }
  formatTimestamp(t: any) { return t?.toDate ? t.toDate() : new Date(t || new Date()); }
  ngOnDestroy() { if(this.unsubscribe) this.unsubscribe(); if(this.notifUnsubscribe) this.notifUnsubscribe(); }
}
