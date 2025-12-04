import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { auth, db } from '../../../core/firebase.config'; 
import { collection, query, where, onSnapshot, Unsubscribe, orderBy, limit } from 'firebase/firestore';
import { ChatComponent } from '../chat/chat.component';

interface Job { id: string; description: string; imageUrl?: string; imageUrls?: string[]; status: string; createdAt: any; acceptedPrice?: number; userEmail?: string; unreadCount?: number; proposals?: any[]; }

@Component({
  selector: 'app-worker-profile',
  standalone: true,
  imports: [CommonModule, ChatComponent],
  template: `
    <div class="space-y-6 pb-20 relative">
      <div class="bg-green-600 rounded-2xl p-6 text-white shadow-lg">
        <h3 class="text-xl font-bold">Espace Artisan</h3>
        <p class="opacity-80">Mes Chantiers</p>
      </div>
      
      <!-- FILTRES -->
      <div class="flex gap-2 overflow-x-auto pb-2 no-scrollbar">
        <button (click)="setFilter('assigned')" class="px-4 py-2 rounded-full text-sm font-bold transition whitespace-nowrap" [class]="filterStatus === 'assigned' ? 'bg-green-600 text-white shadow' : 'bg-white text-gray-600 border'">En Cours ({{ getCount('assigned') }})</button>
        <button (click)="setFilter('proposal')" class="px-4 py-2 rounded-full text-sm font-bold transition whitespace-nowrap" [class]="filterStatus === 'proposal' ? 'bg-blue-600 text-white shadow' : 'bg-white text-gray-600 border'">Propositions ({{ getCount('proposal') }})</button>
        <button (click)="setFilter('completed')" class="px-4 py-2 rounded-full text-sm font-bold transition whitespace-nowrap" [class]="filterStatus === 'completed' ? 'bg-gray-600 text-white shadow' : 'bg-white text-gray-600 border'">Terminés ({{ getCount('completed') }})</button>
      </div>

      <!-- LISTE -->
      <div>
        @if (!isLoading && filteredJobs.length > 0) {
           <div class="space-y-4">
             @for (job of filteredJobs; track job.id) {
               <div class="bg-white p-4 rounded-xl shadow-sm border-l-4 flex flex-col gap-2" [class.border-green-500]="job.status === 'assigned'">
                 <div class="flex justify-between items-start">
                   <div>
                     <h5 class="font-bold text-gray-800 line-clamp-1">{{ job.description }}</h5>
                     <span class="text-xs text-gray-500">{{ formatTimestamp(job.createdAt) | date:'dd/MM/yyyy' }}</span>
                   </div>
                   @if (job.unreadCount && job.unreadCount > 0) { <span class="bg-red-500 text-white text-xs px-2 py-0.5 rounded-full animate-bounce">{{ job.unreadCount }}</span> }
                 </div>
                 <div class="flex justify-between items-end mt-1">
                   <div class="text-xs"><p class="font-bold text-green-700 bg-green-50 px-2 py-1 rounded inline-block">Devis: {{ job.acceptedPrice || 'En attente' }} TND</p></div>
                   <div class="flex gap-2">
                     <button (click)="viewJobDetails(job)" class="bg-gray-100 text-gray-700 py-1.5 px-3 rounded-lg text-xs font-bold border">Détails 📋</button>
                     @if (job.status === 'assigned') {
                       <button (click)="openChat(job)" class="bg-blue-50 text-blue-600 py-1.5 px-3 rounded-lg text-xs font-bold border border-blue-200">Chat 💬</button>
                       <button (click)="contactClient(job)" class="bg-green-50 text-green-700 py-1.5 px-3 rounded-lg text-xs font-bold border border-green-200">📞</button>
                     }
                   </div>
                 </div>
               </div>
             }
           </div>
        } @else { <div class="text-center py-10 text-gray-500">Aucun chantier.</div> }
      </div>

      <!-- Modale Détails -->
      @if (selectedJobDetails) {
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4 animate-fade-in">
          <div class="bg-white w-full max-w-md rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
            <div class="p-4 border-b flex justify-between items-center bg-gray-50"><h3 class="font-bold">Détails</h3><button (click)="closeDetails()" class="text-xl">✕</button></div>
            <div class="flex-grow overflow-y-auto p-4 space-y-3">
              <div><label class="text-xs font-bold text-gray-500 uppercase">Description</label><p class="text-sm bg-gray-50 p-3 rounded mt-1">{{ selectedJobDetails.description }}</p></div>
              @if(selectedJobDetails.imageUrl) { <img [src]="selectedJobDetails.imageUrl" class="w-full h-40 object-cover rounded-lg mt-2"> }
              <div class="pt-2"><button (click)="openChat(selectedJobDetails); closeDetails()" class="w-full py-3 bg-blue-600 text-white font-bold rounded-xl shadow-md">Chat</button></div>
            </div>
          </div>
        </div>
      }

      @if (selectedJobForChat) {
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div class="bg-white w-full max-w-md rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[80vh]">
            <div class="p-3 bg-gray-100 border-b flex justify-between items-center"><h3 class="font-bold">Chat</h3><button (click)="closeChat()" class="text-xl">×</button></div>
            <app-chat [jobId]="selectedJobForChat.id" class="flex-grow overflow-hidden"></app-chat>
          </div>
        </div>
      }
    </div>
  `
})
export class WorkerProfileComponent implements OnInit, OnDestroy {
  allJobs: Job[] = []; filteredJobs: Job[] = []; isLoading = true; filterStatus: 'assigned' | 'proposal' | 'completed' = 'assigned';
  selectedJobForChat: Job | null = null; selectedJobDetails: Job | null = null;
  private unsubscribes: any[] = []; private cdr = inject(ChangeDetectorRef); currentUser = auth.currentUser;

  ngOnInit() {
    if (!this.currentUser) return;
    const uid = this.currentUser.uid;
    const qAssigned = query(collection(db, 'jobs'), where('workerId', '==', uid));
    const qProposals = query(collection(db, 'jobs'), where('status', '==', 'analyzing'));
    const unsub1 = onSnapshot(qAssigned, (s) => this.updateJobs(s.docs, 'assigned'));
    const unsub2 = onSnapshot(qProposals, (s) => this.updateJobs(s.docs, 'analyzing'));
    this.unsubscribes.push(unsub1, unsub2);
  }
  private rawJobsMap = new Map<string, Job>();
  updateJobs(docs: any[], source: string) {
    docs.forEach(doc => {
      const job = { id: doc.id, ...doc.data() } as Job;
      if (source === 'analyzing') {
        if (job.proposals?.some((p: any) => p.workerId === this.currentUser?.uid)) this.rawJobsMap.set(job.id, job);
        else this.rawJobsMap.delete(job.id);
      } else { this.rawJobsMap.set(job.id, job); }
    });
    this.allJobs = Array.from(this.rawJobsMap.values());
    this.applyFilter(); this.isLoading = false; this.cdr.detectChanges();
  }
  setFilter(status: 'assigned' | 'proposal' | 'completed') { this.filterStatus = status; this.applyFilter(); }
  applyFilter() {
    if (this.filterStatus === 'assigned') this.filteredJobs = this.allJobs.filter(j => j.status === 'assigned');
    else if (this.filterStatus === 'completed') this.filteredJobs = this.allJobs.filter(j => j.status === 'completed');
    else this.filteredJobs = this.allJobs.filter(j => j.status === 'analyzing');
    this.filteredJobs.sort((a, b) => this.formatTimestamp(b.createdAt).getTime() - this.formatTimestamp(a.createdAt).getTime());
  }
  getCount(type: string) {
    if (type === 'assigned') return this.allJobs.filter(j => j.status === 'assigned').length;
    if (type === 'completed') return this.allJobs.filter(j => j.status === 'completed').length;
    return this.allJobs.filter(j => j.status === 'analyzing').length;
  }
  viewJobDetails(job: Job) { this.selectedJobDetails = job; }
  closeDetails() { this.selectedJobDetails = null; }
  openChat(job: Job) { this.selectedJobForChat = job; }
  closeChat() { this.selectedJobForChat = null; }
  contactClient(job: Job) { if(job.userEmail) window.location.href = `mailto:${job.userEmail}`; }
  getAllMedia(job: Job): string[] { return job.imageUrls || [job.imageUrl || '']; }
  isVideo(url: string): boolean { return !!url.match(/\.(mp4|webm)(\?.*)?$/i); }
  formatTimestamp(t: any) { return t?.toDate ? t.toDate() : new Date(t || new Date()); }
  ngOnDestroy() { this.unsubscribes.forEach(u => u()); }
}
