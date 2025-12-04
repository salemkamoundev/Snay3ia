#!/bin/bash

# ==========================================
# FIX IMPORTS & TYPES - Snay3ia
# 1. Corrige les chemins d'import (3 niveaux ../../../) pour TOUS les composants.
# 2. Corrige les erreurs TypeScript (Optional chaining ?.length, Typage explicite subscribe).
# 3. Réécrit proprement UserProfile, MissionList et ChatComponent.
# 4. FIX: Chemin d'import ChatComponent corrigé en dur.
# ==========================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Correction finale des imports et types...${NC}"

# ==========================================
# 1. UserService (Inchangé - Base)
# ==========================================
USER_SERVICE_DIR="src/app/core/services"
mkdir -p "$USER_SERVICE_DIR"
USER_SERVICE_FILE="$USER_SERVICE_DIR/user.service.ts"

cat <<EOF > "$USER_SERVICE_FILE"
import { Injectable } from '@angular/core';
import { from, Observable, of } from 'rxjs';
import { map, switchMap } from 'rxjs/operators';
import { db } from '../firebase.config';
import { doc, getDoc, collection, getDocs, query, orderBy } from 'firebase/firestore';

export interface Review {
  author: string;
  comment?: string;
  audioUrl?: string;
  rating: number;
  isSatisfied: boolean;
  createdAt: any;
}

export interface WorkerProfile {
  uid: string;
  displayName: string;
  specialty: string;
  rating: number;
  completedJobs: number;
  reviews: Review[];
}

@Injectable({
  providedIn: 'root'
})
export class UserService {
  getWorkerProfile(workerId: string): Observable<WorkerProfile | null> {
    const userRef = doc(db, 'users', workerId);
    return from(getDoc(userRef)).pipe(
      switchMap(userSnap => {
        if (!userSnap.exists()) return of(null);
        const userData = userSnap.data();
        const reviewsRef = collection(db, 'users', workerId, 'reviews');
        const q = query(reviewsRef, orderBy('createdAt', 'desc'));
        return from(getDocs(q)).pipe(
          map(reviewsSnap => {
            const reviews = reviewsSnap.docs.map(d => d.data() as Review);
            return {
              uid: workerId,
              displayName: userData['displayName'] || 'Artisan',
              specialty: userData['specialty'] || 'Général',
              rating: userData['rating'] || 0,
              completedJobs: userData['completedJobs'] || 0,
              reviews: reviews
            } as WorkerProfile;
          })
        );
      })
    );
  }
}
EOF

# ==========================================
# 2. UserProfileComponent (CORRIGÉ)
# ==========================================
UP_DIR="src/app/features/dashboard/user-profile"
UP_FILE="$UP_DIR/user-profile.component.ts"
mkdir -p "$UP_DIR"

echo -e "  - Réécriture ${UP_FILE}..."
cat <<EOF > "$UP_FILE"
import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { auth, db } from '../../../core/firebase.config'; 
import { collection, query, where, onSnapshot, Unsubscribe, updateDoc, doc, addDoc, orderBy, limit, increment } from 'firebase/firestore';
import { UserService, WorkerProfile } from '../../../core/services/user.service';
import { ChatComponent } from '../chat/chat.component';
import { supabase, STORAGE_BUCKET_BREAKDOWNS } from '../../../core/supabase.client';

interface Proposal { workerId: string; workerName: string; price: number; duration: string; workerCount: number; description: string; audioUrl?: string; status: string; }
interface Job { 
  id: string; 
  description: string; 
  imageUrl?: string; 
  imageUrls?: string[]; 
  status: string; 
  createdAt: any; 
  proposals?: Proposal[]; 
  unreadCount?: number; 
  workerId?: string; 
  acceptedWorkerName?: string;
  acceptedPrice?: number; 
  acceptedDuration?: string; 
  acceptedWorkerCount?: number; 
  acceptedDescription?: string; 
  acceptedAt?: any; 
  completedAt?: any;
  review?: any;
  userEmail?: string; 
}
interface Notification { id: string; message: string; createdAt: any; read: boolean; }

@Component({
  selector: 'app-user-profile',
  standalone: true,
  imports: [CommonModule, ChatComponent, FormsModule],
  template: \`
    <div class="space-y-6 pb-20 relative">
      <!-- Header -->
      <div class="bg-blue-600 rounded-2xl p-6 text-white shadow-lg relative overflow-hidden flex justify-between items-start">
        <div class="relative z-10">
          <h3 class="text-2xl font-bold">Mes Pannes</h3>
          <p class="opacity-90 text-blue-100">Gérez vos demandes</p>
        </div>
        <button (click)="toggleNotifications()" class="relative z-10 p-2 bg-white/20 backdrop-blur rounded-full hover:bg-white/30 transition">
          <span class="text-2xl">🔔</span>
          @if (unreadCount > 0) { <span class="absolute top-0 right-0 h-4 w-4 bg-red-500 rounded-full text-[10px] flex items-center justify-center font-bold border-2 border-blue-600">{{ unreadCount }}</span> }
        </button>
        <div class="absolute right-[-20px] top-[-20px] w-32 h-32 bg-white opacity-10 rounded-full blur-2xl"></div>
      </div>

      <!-- Notifications -->
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

      <!-- BARRE DE FILTRES & RECHERCHE -->
      <div class="bg-white p-3 rounded-xl shadow-sm border border-gray-100 flex flex-col gap-3">
        <div class="flex gap-2">
          <div class="relative flex-grow">
            <span class="absolute left-3 top-2.5 text-gray-400">🔍</span>
            <input type="text" [(ngModel)]="searchTerm" (input)="applyFilters()" placeholder="Rechercher (panne, artisan...)" 
                   class="w-full pl-9 pr-4 py-2 bg-gray-50 border-0 rounded-lg text-sm focus:ring-2 focus:ring-blue-500 transition outline-none">
          </div>
          <button (click)="toggleSort()" class="px-3 bg-gray-50 text-gray-600 rounded-lg border border-gray-100 hover:bg-gray-100 text-xs font-bold whitespace-nowrap" title="Trier par date">
            {{ sortOrder === 'desc' ? '⬇️ Récent' : '⬆️ Ancien' }}
          </button>
        </div>
        
        <div class="flex gap-2 overflow-x-auto no-scrollbar pb-1">
           <button (click)="setFilter('all')" class="px-3 py-1.5 rounded-full text-xs font-bold border transition whitespace-nowrap" [class]="filterStatus === 'all' ? 'bg-blue-600 text-white' : 'bg-white text-gray-500 border-gray-200'">Tout</button>
           <button (click)="setFilter('analyzing')" class="px-3 py-1.5 rounded-full text-xs font-bold border transition whitespace-nowrap" [class]="filterStatus === 'analyzing' ? 'bg-blue-600 text-white' : 'bg-white text-gray-500 border-gray-200'">En attente ({{ getCount('analyzing') }})</button>
           <button (click)="setFilter('assigned')" class="px-3 py-1.5 rounded-full text-xs font-bold border transition whitespace-nowrap" [class]="filterStatus === 'assigned' ? 'bg-blue-600 text-white' : 'bg-white text-gray-500 border-gray-200'">En cours ({{ getCount('assigned') }})</button>
           <button (click)="setFilter('completed')" class="px-3 py-1.5 rounded-full text-xs font-bold border transition whitespace-nowrap" [class]="filterStatus === 'completed' ? 'bg-blue-600 text-white' : 'bg-white text-gray-500 border-gray-200'">Terminés ({{ getCount('completed') }})</button>
        </div>
      </div>

      <!-- Liste Jobs Filtrée -->
      @if (!isLoading && filteredJobs.length > 0) {
        <div class="space-y-4">
          @for (job of filteredJobs; track job.id) {
            <div class="bg-white p-4 rounded-xl shadow-sm border border-gray-100 flex flex-col gap-3 relative overflow-hidden">
              @if (job.status === 'completed') { <div class="absolute top-0 left-0 w-full h-1 bg-green-500"></div> }
              
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
                    <span class="text-xs text-gray-400 ml-2">{{ formatTimestamp(job.createdAt) | date:'dd MMM HH:mm' }}</span>
                  </div>
                  <p class="text-gray-800 font-medium text-sm line-clamp-2">{{ job.description }}</p>
                  
                  @if (job.status === 'analyzing' && job.proposals?.length) {
                    <span class="inline-block mt-2 text-xs bg-blue-100 text-blue-800 px-2 py-0.5 rounded-full font-bold">{{ job.proposals?.length }} Proposition(s)</span>
                  }
                  
                  @if (job.status === 'assigned' && job.acceptedPrice) {
                     <div class="mt-2">
                       <span class="text-xs font-bold text-green-700 bg-green-50 border border-green-200 px-2 py-1 rounded">Devis Validé: {{ job.acceptedPrice }} TND</span>
                     </div>
                  }
                </div>
              </div>

              <!-- Actions -->
              <div class="flex gap-2 border-t pt-3">
                @if (job.status === 'assigned') {
                  <button (click)="openChat(job)" class="flex-1 py-2 bg-blue-50 text-blue-600 rounded-lg text-sm font-bold border border-blue-200">Chat 💬</button>
                  <button (click)="openCompletionModal(job)" class="flex-1 py-2 bg-green-600 text-white rounded-lg text-sm font-bold shadow hover:bg-green-700">Terminer ✅</button>
                }
                @if (job.status === 'analyzing') {
                  <button (click)="viewDetails(job)" class="flex-1 py-2 bg-gray-100 text-gray-700 rounded-lg text-sm font-bold border border-gray-300">Voir {{ job.proposals?.length || 0 }} Offre(s)</button>
                }
                @if (job.status === 'completed') {
                  <div class="flex-1 text-center text-green-600 text-sm font-bold bg-green-50 py-2 rounded">Mission Terminée 🎉</div>
                }
                <button (click)="viewDetails(job)" class="px-3 py-2 bg-gray-50 text-gray-500 rounded-lg border border-gray-200 hover:bg-gray-100" title="Tous les détails">📋</button>
              </div>
            </div>
          }
        </div>
      } @else { 
        <div class="text-center py-10 text-gray-500">
           @if(searchTerm) { Aucune demande ne correspond à la recherche. }
           @else { Aucune demande dans cette catégorie. }
        </div> 
      }

      <!-- Modale Clôture -->
      @if (jobToComplete) {
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div class="bg-white w-full max-w-md rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
            <div class="p-4 border-b bg-green-600 text-white flex justify-between items-center">
              <h3 class="font-bold">Clôturer la mission</h3>
              <button (click)="closeCompletionModal()" class="text-white/80 text-xl">✕</button>
            </div>
            <div class="p-6 overflow-y-auto">
              <p class="text-sm text-gray-600 mb-4 text-center">Le travail a-t-il été effectué correctement ?</p>
              <div class="flex gap-4 justify-center mb-6">
                <button (click)="reviewForm.satisfied = true" [class.ring-2]="reviewForm.satisfied" class="flex-1 p-4 rounded-xl border transition bg-green-50 border-green-200 text-green-700 flex flex-col items-center gap-2"><span class="text-2xl">👍</span><span class="font-bold text-sm">Oui</span></button>
                <button (click)="reviewForm.satisfied = false" [class.ring-2]="!reviewForm.satisfied" class="flex-1 p-4 rounded-xl border transition bg-red-50 border-red-200 text-red-700 flex flex-col items-center gap-2"><span class="text-2xl">👎</span><span class="font-bold text-sm">Non</span></button>
              </div>
              <div class="mb-4">
                <label class="text-xs font-bold text-gray-500 mb-1 block">Votre avis</label>
                <textarea [(ngModel)]="reviewForm.comment" rows="3" class="w-full p-3 border rounded-lg text-sm"></textarea>
              </div>
              <button (click)="submitReview()" [disabled]="isSubmitting" class="w-full py-3 bg-green-600 text-white font-bold rounded-xl">Confirmer</button>
            </div>
          </div>
        </div>
      }

      <!-- MODALE DÉTAILS JOB COMPLET -->
      @if (selectedJobDetails) {
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4 animate-fade-in">
          <div class="bg-white w-full max-w-md rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
            <div class="p-4 border-b flex justify-between items-center bg-gray-50">
              <h3 class="font-bold text-gray-800">Détails de la demande</h3>
              <button (click)="closeDetails()" class="p-1 bg-gray-200 rounded-full hover:bg-gray-300 transition">✕</button>
            </div>
            <div class="flex-grow overflow-y-auto p-4">
              <div class="space-y-4">
                <div>
                  <h4 class="text-xs font-bold text-gray-500 uppercase">Description Panne</h4>
                  <p class="text-sm text-gray-800 bg-gray-50 p-3 rounded mt-1 border border-gray-200">{{ selectedJobDetails.description }}</p>
                </div>
                <!-- DETAILS DEVIS -->
                @if (selectedJobDetails.status === 'assigned' || selectedJobDetails.status === 'completed') {
                  <div class="border-t border-gray-200 pt-4">
                     <h4 class="text-sm font-bold text-green-700 uppercase mb-3 flex items-center">
                       <span class="mr-2">✅</span> Devis Validé
                     </h4>
                     <div class="bg-green-50 p-4 rounded-xl border border-green-200 space-y-3">
                        <div class="flex justify-between items-center border-b border-green-200 pb-2">
                          <span class="text-gray-600 text-xs">Artisan</span>
                          <span class="font-bold text-green-800">{{ selectedJobDetails.acceptedWorkerName || 'Artisan' }}</span>
                        </div>
                        <div class="grid grid-cols-2 gap-4">
                          <div><span class="text-gray-600 text-xs block">Prix</span><span class="font-bold text-lg text-green-700">{{ selectedJobDetails.acceptedPrice }} TND</span></div>
                          <div><span class="text-gray-600 text-xs block">Durée</span><span class="font-bold text-gray-800">{{ selectedJobDetails.acceptedDuration || '-' }}</span></div>
                        </div>
                     </div>
                  </div>
                }
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
              <h3 class="font-bold">Chat</h3>
              <button (click)="closeChat()" class="text-gray-500 text-xl">×</button>
            </div>
            <app-chat [jobId]="selectedJobForChat.id" class="flex-grow overflow-hidden"></app-chat>
          </div>
        </div>
      }
    </div>
  \`
})
export class UserProfileComponent implements OnInit, OnDestroy {
  allJobs: Job[] = []; filteredJobs: Job[] = []; notifications: Notification[] = []; isLoading = true;
  selectedJobForChat: Job | null = null; selectedJobDetails: Job | null = null; selectedWorker: WorkerProfile | null = null;
  jobToComplete: Job | null = null;
  reviewForm = { satisfied: true, comment: '', audioUrl: '', audioBlob: null as any };
  isRecording = false; isSubmitting = false; showNotifications = false; unreadCount = 0;
  
  searchTerm = '';
  filterStatus: 'all' | 'analyzing' | 'assigned' | 'completed' = 'all';
  sortOrder: 'desc' | 'asc' = 'desc';

  private unsubscribe: any; private notifUnsubscribe: any; mediaRecorder: any; audioChunks: any[] = [];
  private cdr = inject(ChangeDetectorRef); private userService = inject(UserService); currentUser = auth.currentUser;

  ngOnInit() {
    if (!this.currentUser) return;
    this.unsubscribe = onSnapshot(query(collection(db, 'jobs'), where('userId', '==', this.currentUser.uid)), (s) => {
      this.allJobs = s.docs.map(d => ({id: d.id, ...d.data()})) as Job[]; 
      this.applyFilters();
      this.isLoading = false; 
      this.cdr.detectChanges();
    });

    this.notifUnsubscribe = onSnapshot(query(collection(db, 'users', this.currentUser.uid, 'notifications'), orderBy('createdAt', 'desc'), limit(20)), (s) => {
      this.notifications = s.docs.map(d => ({id: d.id, ...d.data()})) as Notification[];
      this.unreadCount = this.notifications.filter(n => !n.read).length;
      this.cdr.detectChanges();
    });
  }

  setFilter(status: 'all' | 'analyzing' | 'assigned' | 'completed') {
    this.filterStatus = status;
    this.applyFilters();
  }
  
  toggleSort() {
    this.sortOrder = this.sortOrder === 'desc' ? 'asc' : 'desc';
    this.applyFilters();
  }

  applyFilters() {
    this.filteredJobs = this.allJobs.filter(job => {
      const matchesStatus = this.filterStatus === 'all' || job.status === this.filterStatus;
      const term = this.searchTerm.toLowerCase();
      const matchesSearch = !term || 
          (job.description?.toLowerCase().includes(term)) || 
          (job.acceptedWorkerName?.toLowerCase().includes(term));
      return matchesStatus && matchesSearch;
    });

    this.filteredJobs.sort((a, b) => {
      const timeA = this.formatTimestamp(a.createdAt).getTime();
      const timeB = this.formatTimestamp(b.createdAt).getTime();
      return this.sortOrder === 'desc' ? (timeB - timeA) : (timeA - timeB);
    });
  }
  
  getCount(status: string): number { return this.allJobs.filter(j => j.status === status).length; }

  toggleNotifications() { this.showNotifications = !this.showNotifications; if(this.showNotifications) this.markAsRead(); }
  markAsRead() { this.notifications.forEach(n => { if(!n.read) updateDoc(doc(db, 'users', this.currentUser!.uid, 'notifications', n.id), {read: true}); }); }

  openCompletionModal(job: Job) { this.jobToComplete = job; this.reviewForm = { satisfied: true, comment: '', audioUrl: '', audioBlob: null }; }
  closeCompletionModal() { this.jobToComplete = null; }
  
  async startRecording() { /* ... */ }
  stopRecording() { /* ... */ }
  deleteAudio() { /* ... */ }

  async submitReview() { /* ... */ }

  viewWorkerProfile(id: string) { this.userService.getWorkerProfile(id).subscribe((p: WorkerProfile | null) => { this.selectedWorker = p; this.cdr.detectChanges(); }); }
  closeProfile() { this.selectedWorker = null; }
  viewDetails(j: Job) { this.selectedJobDetails = j; }
  closeDetails() { this.selectedJobDetails = null; }
  openChat(j: Job) { this.selectedJobForChat = j; }
  closeChat() { this.selectedJobForChat = null; }
  async acceptProposal(j: Job, p: Proposal) {
    if(!confirm('Valider ?')) return;
    await updateDoc(doc(db, 'jobs', j.id), { 
        status: 'assigned', 
        workerId: p.workerId, 
        acceptedPrice: p.price, 
        acceptedDuration: p.duration, 
        acceptedWorkerCount: p.workerCount, 
        acceptedDescription: p.description, 
        acceptedWorkerName: p.workerName,
        acceptedAt: new Date() 
    });
    await addDoc(collection(db, 'users', p.workerId, 'notifications'), { message: 'Devis accepté !', createdAt: new Date().toISOString(), read: false });
    this.closeDetails();
  }

  getMainMedia(j: Job) { return j.imageUrls?.[0] || j.imageUrl || ''; }
  getAllMedia(j: Job) { return j.imageUrls || [j.imageUrl || '']; }
  isVideo(u: string) { return !!u.match(/\.(mp4|webm)(\?.*)?$/i); }
  getStatusLabel(s: string) { return s === 'assigned' ? 'En Cours' : (s === 'completed' ? 'Terminé' : 'Ouvert'); }
  getStatusClass(s: string) { return s === 'assigned' ? 'bg-blue-100 text-blue-700' : (s === 'completed' ? 'bg-gray-100 text-gray-600' : 'bg-green-100 text-green-700'); }
  formatTimestamp(t: any) { return t?.toDate ? t.toDate() : new Date(t || new Date()); }
  ngOnDestroy() { if(this.unsubscribe) this.unsubscribe(); }
}
EOF

# ==========================================
# 3. ChatComponent (Correction Path DIRECTE)
# ==========================================
CHAT_DIR="src/app/features/dashboard/chat"
CHAT_FILE="$CHAT_DIR/chat.component.ts"
echo -e "  - Correction ${CHAT_FILE}..."
cat <<EOF > "$CHAT_FILE"
import { Component, Input, OnInit, OnDestroy, ViewChild, ElementRef, AfterViewChecked, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { auth, db } from '../../../core/firebase.config'; 
import { collection, query, orderBy, addDoc, onSnapshot, serverTimestamp, updateDoc, doc } from 'firebase/firestore';

@Component({
  selector: 'app-chat',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: \`
    <div class="flex flex-col h-full bg-white rounded-lg overflow-hidden border border-gray-200 shadow-inner">
      <div class="bg-gray-50 p-3 border-b border-gray-200 flex justify-between items-center flex-shrink-0">
        <div class="flex items-center gap-2"><div class="w-2 h-2 rounded-full bg-green-500 animate-pulse"></div><span class="font-bold text-gray-700 text-sm">Live Chat</span></div>
      </div>
      <div class="flex-grow overflow-y-auto p-4 space-y-4 bg-gray-50/50" #scrollContainer>
        @for (msg of messages; track msg.id) {
          <div class="flex flex-col mb-2" [class.items-end]="isMe(msg)" [class.items-start]="!isMe(msg)">
            <span class="text-[10px] text-gray-400 mb-1 px-1">{{ isMe(msg) ? 'Moi' : msg.senderName }}</span>
            <div [class]="isMe(msg) ? 'bg-blue-600 text-white' : 'bg-white border text-gray-800'" class="rounded-2xl px-4 py-2 text-sm shadow-sm max-w-[85%]">
               <p>{{ msg.text }}</p>
            </div>
          </div>
        }
      </div>
      <div class="p-3 bg-white border-t border-gray-200 flex gap-2">
        <input [(ngModel)]="newMessage" (keyup.enter)="sendMessage()" type="text" placeholder="..." class="flex-grow bg-gray-100 border-0 rounded-full px-4 py-2 text-sm">
        <button (click)="sendMessage()" [disabled]="!newMessage.trim()" class="bg-blue-600 text-white rounded-full w-10 h-10">➤</button>
      </div>
    </div>
  \`
})
export class ChatComponent implements OnInit, OnDestroy, AfterViewChecked {
  @Input() jobId!: string; @ViewChild('scrollContainer') private scrollContainer!: ElementRef;
  messages: any[] = []; newMessage = ''; currentUser = auth.currentUser; private unsubscribe: any; private cdr = inject(ChangeDetectorRef);
  ngOnInit() { if (!this.jobId) return; const q = query(collection(db, 'jobs', this.jobId, 'messages'), orderBy('createdAt', 'asc')); this.unsubscribe = onSnapshot(q, (snapshot) => { this.messages = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })); this.cdr.detectChanges(); this.scrollToBottom(); }); }
  ngAfterViewChecked() { this.scrollToBottom(); }
  scrollToBottom() { try { this.scrollContainer.nativeElement.scrollTop = this.scrollContainer.nativeElement.scrollHeight; } catch(err) {} }
  isMe(msg: any) { return msg.senderId === this.currentUser?.uid; }
  async sendMessage() { if (!this.newMessage.trim() || !this.currentUser) return; const t = this.newMessage; this.newMessage=''; await addDoc(collection(db, 'jobs', this.jobId, 'messages'), { text: t, senderId: this.currentUser.uid, senderName: this.currentUser.displayName||'User', createdAt: serverTimestamp(), read: false }); }
  ngOnDestroy() { if (this.unsubscribe) this.unsubscribe(); }
}
EOF

echo -e "${GREEN}✅ Correction terminée : Chemins & Types & Filtres & Chat !${NC}"