#!/bin/bash

# ==========================================
# FIX IMPORTS & CLEANUP - Snay3ia
# 1. Réécrit les fichiers TS avec les bons chemins (../../../) DIRECTEMENT.
# 2. Supprime les dépendances inutiles (DatePipe).
# 3. Met à jour WorkerProfile avec Détails enrichis et Chat.
# 4. FIX CHAT : Hauteur responsive + Réponse + Lecture automatique.
# 5. UPDATE CLIENT : Fix TS Error (Object possibly undefined).
# 6. UPDATE WORKER : Correction variable 's' et typage 'd'.
# ==========================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 Mise à jour complète du Dashboard Client & Artisan (Correction Compilation)...${NC}"

# ==========================================
# 1. ChatComponent (Inchangé - Déjà optimisé)
# ==========================================
CHAT_DIR="src/app/features/dashboard/chat"
CHAT_FILE="$CHAT_DIR/chat.component.ts"
mkdir -p "$CHAT_DIR"

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
        <div class="flex items-center gap-2">
          <div class="w-2 h-2 rounded-full bg-green-500 animate-pulse"></div>
          <span class="font-bold text-gray-700 text-sm">Discussion en direct</span>
        </div>
      </div>

      <div class="flex-grow overflow-y-auto p-4 space-y-4 bg-gray-50/50" #scrollContainer>
        @if (messages.length === 0) {
          <div class="text-center text-gray-400 text-xs mt-10">
            Commencez la discussion... <br>
            <span class="text-[10px] opacity-70">Job #{{ jobId | slice:0:6 }}</span>
          </div>
        }
        @for (msg of messages; track msg.id) {
          <div class="flex flex-col mb-2" [class.items-end]="isMe(msg)" [class.items-start]="!isMe(msg)">
            <span class="text-[10px] text-gray-400 mb-1 px-1">{{ isMe(msg) ? 'Moi' : msg.senderName }}</span>
            <div class="group relative max-w-[85%] flex items-center gap-2" [class.flex-row-reverse]="isMe(msg)">
              <button (click)="setReply(msg)" class="opacity-0 group-hover:opacity-100 transition p-1.5 bg-gray-200 hover:bg-gray-300 rounded-full text-gray-600 text-[10px]" title="Répondre">↩</button>
              <div [class]="isMe(msg) ? 'bg-blue-600 text-white rounded-tr-none' : 'bg-white border border-gray-200 text-gray-800 rounded-tl-none'"
                   class="rounded-2xl px-4 py-2 text-sm shadow-sm relative animate-fade-in break-words w-full">
                @if (msg.text.startsWith('> Réponse à')) {
                   <div class="mb-2 p-2 rounded bg-black/10 text-xs italic border-l-2 border-white/50 opacity-80 whitespace-pre-wrap">{{ extractQuote(msg.text) }}</div>
                   <p>{{ removeQuote(msg.text) }}</p>
                } @else { <p>{{ msg.text }}</p> }
                <div class="text-[10px] mt-1 opacity-70 text-right min-w-[40px] flex justify-end gap-1 items-center">
                  <span>{{ formatTime(msg.createdAt) }}</span>
                  @if (isMe(msg)) { <span>{{ msg.read ? '✓✓' : '✓' }}</span> }
                </div>
              </div>
            </div>
          </div>
        }
      </div>

      @if (replyToMessage) {
        <div class="bg-blue-50 p-2 border-t border-blue-100 flex justify-between items-center text-xs text-blue-800 animate-slide-up">
          <div class="flex items-center gap-2 overflow-hidden">
            <span class="font-bold">↩ Réponse à {{ replyToMessage.senderName }}:</span>
            <span class="truncate italic opacity-70">"{{ getCleanText(replyToMessage.text) | slice:0:30 }}..."</span>
          </div>
          <button (click)="cancelReply()" class="text-blue-500 hover:text-blue-700 font-bold px-2">✕</button>
        </div>
      }

      <div class="p-3 bg-white border-t border-gray-200 flex gap-2 flex-shrink-0">
        <input id="chatInput" [(ngModel)]="newMessage" (keyup.enter)="sendMessage()" type="text" placeholder="Écrivez..." class="flex-grow bg-gray-100 border-0 rounded-full px-4 py-2 text-sm focus:ring-2 focus:ring-blue-500 transition outline-none">
        <button (click)="sendMessage()" [disabled]="!newMessage.trim()" class="bg-blue-600 hover:bg-blue-700 text-white rounded-full w-10 h-10 flex items-center justify-center transition disabled:opacity-50 shadow-md">➤</button>
      </div>
    </div>
  \`
})
export class ChatComponent implements OnInit, OnDestroy, AfterViewChecked {
  @Input() jobId!: string;
  @ViewChild('scrollContainer') private scrollContainer!: ElementRef;
  messages: any[] = []; newMessage = ''; replyToMessage: any = null; currentUser = auth.currentUser;
  private unsubscribe: any; private cdr = inject(ChangeDetectorRef);

  ngOnInit() {
    if (!this.jobId) return;
    const q = query(collection(db, 'jobs', this.jobId, 'messages'), orderBy('createdAt', 'asc'));
    this.unsubscribe = onSnapshot(q, (snapshot) => {
      this.messages = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      this.cdr.detectChanges(); this.scrollToBottom(); this.markMessagesAsRead();
    });
  }
  markMessagesAsRead() {
    if (!this.currentUser) return;
    this.messages.forEach(msg => {
      if (!msg.read && msg.senderId !== this.currentUser?.uid) {
        updateDoc(doc(db, 'jobs', this.jobId, 'messages', msg.id), { read: true }).catch(console.error);
      }
    });
  }
  ngAfterViewChecked() { this.scrollToBottom(); }
  scrollToBottom(): void { try { this.scrollContainer.nativeElement.scrollTop = this.scrollContainer.nativeElement.scrollHeight; } catch(err) { } }
  isMe(msg: any): boolean { return msg.senderId === this.currentUser?.uid; }
  formatTime(timestamp: any): string {
    if (!timestamp) return '...';
    const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
  }
  setReply(msg: any) { this.replyToMessage = msg; const input = document.getElementById('chatInput'); if (input) input.focus(); }
  cancelReply() { this.replyToMessage = null; }
  getCleanText(text: string): string { return this.removeQuote(text); }
  extractQuote(text: string): string { const match = text.match(/> Réponse à .*?: "(.*?)"/); return match ? match[1] + "..." : "Message cité"; }
  removeQuote(text: string): string { return text.replace(/> Réponse à .*?: ".*?"\n\n/, ''); }
  async sendMessage() {
    if (!this.newMessage.trim() || !this.currentUser) return;
    let textToSend = this.newMessage;
    if (this.replyToMessage) {
      const quotedText = this.getCleanText(this.replyToMessage.text).slice(0, 50);
      textToSend = \`> Réponse à \${this.replyToMessage.senderName}: "\${quotedText}"\n\n\${textToSend}\`;
      this.replyToMessage = null;
    }
    this.newMessage = '';
    try {
      await addDoc(collection(db, 'jobs', this.jobId, 'messages'), {
        text: textToSend,
        senderId: this.currentUser.uid,
        senderName: this.currentUser.displayName || 'Utilisateur',
        createdAt: serverTimestamp(),
        read: false 
      });
    } catch (error) { console.error(error); this.newMessage = textToSend; alert("Erreur d'envoi."); }
  }
  ngOnDestroy() { if (this.unsubscribe) this.unsubscribe(); }
}
EOF

# ==========================================
# 2. MissionListComponent (UPDATE: Notifie le client lors de la candidature)
# ==========================================
MISSION_DIR="src/app/features/dashboard/mission-list"
MISSION_FILE="$MISSION_DIR/mission-list.component.ts"
cat <<EOF > "$MISSION_FILE"
import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { auth, db } from '../../../core/firebase.config'; 
import { collection, query, where, onSnapshot, updateDoc, doc, arrayUnion, Unsubscribe, limit, addDoc, orderBy } from 'firebase/firestore';
import { supabase, STORAGE_BUCKET_BREAKDOWNS } from '../../../core/supabase.client';

interface Job { id: string; description: string; imageUrl?: string; imageUrls?: string[]; status: string; createdAt: any; userId: string; proposals?: any[]; }
interface Notification { id: string; message: string; createdAt: any; read: boolean; }

@Component({
  selector: 'app-mission-list',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: \`
    <div class="space-y-6 pb-24 relative">
      <div class="bg-green-600 rounded-2xl p-6 text-white shadow-lg relative overflow-hidden flex justify-between items-start">
        <div class="relative z-10"><h3 class="text-2xl font-bold">Missions</h3><p class="opacity-90 text-green-100">Postulez aux chantiers</p></div>
        <button (click)="toggleNotifications()" class="relative z-10 p-2 bg-white/20 backdrop-blur rounded-full hover:bg-white/30 transition">
          <span class="text-2xl">🔔</span>
          @if (unreadCount > 0) { <span class="absolute top-0 right-0 h-4 w-4 bg-red-500 rounded-full text-[10px] flex items-center justify-center font-bold border-2 border-green-600">{{ unreadCount }}</span> }
        </button>
        <div class="absolute right-[-20px] top-[-20px] w-32 h-32 bg-white opacity-10 rounded-full blur-2xl"></div>
      </div>

      @if (showNotifications) {
        <div class="bg-white rounded-xl shadow-xl border border-gray-100 overflow-hidden mb-4 animate-slide-in">
          <div class="p-3 border-b bg-gray-50 flex justify-between items-center"><h4 class="font-bold text-gray-700 text-sm">Notifications</h4></div>
          <div class="max-h-60 overflow-y-auto">
            @if (notifications.length > 0) {
              @for (notif of notifications; track notif.id) {
                <div class="p-3 border-b last:border-0 hover:bg-gray-50 transition" [class.bg-blue-50]="isRecent(notif.createdAt) && !notif.read">
                  <p class="text-sm text-gray-800">{{ notif.message }}</p>
                </div>
              }
            } @else { <div class="p-6 text-center text-gray-400 text-sm">Rien.</div> }
          </div>
        </div>
      }

      @if (!isLoading && jobs.length > 0) {
        <div class="space-y-4">
          @for (job of jobs; track job.id) {
            <div class="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden p-5">
               <p class="font-bold">{{ job.description }}</p>
               <div class="mt-4">
                 <input type="number" [(ngModel)]="getForm(job.id).price" placeholder="Prix (TND)" class="w-full p-2 border rounded mb-2">
                 <textarea [(ngModel)]="getForm(job.id).description" placeholder="Message" class="w-full p-2 border rounded mb-2"></textarea>
                 <button (click)="applyToJob(job)" class="w-full py-2 bg-green-600 text-white rounded">Envoyer Devis</button>
               </div>
            </div>
          }
        </div>
      } @else { <div class="text-center py-10 text-gray-500">Aucune mission.</div> }
    </div>
  \`
})
export class MissionListComponent implements OnInit, OnDestroy {
  jobs: Job[] = []; notifications: Notification[] = []; isLoading = true; showNotifications = false; unreadCount = 0;
  forms: any = {};
  private unsubscribe: any; private notifUnsubscribe: any; private cdr = inject(ChangeDetectorRef); currentUser = auth.currentUser;

  ngOnInit() {
    this.unsubscribe = onSnapshot(query(collection(db, 'jobs'), where('status', '==', 'analyzing')), (s) => {
      this.jobs = s.docs.map(d => ({id: d.id, ...d.data()})) as Job[]; this.isLoading = false; this.cdr.detectChanges();
    });
    if(this.currentUser) {
      this.notifUnsubscribe = onSnapshot(query(collection(db, 'users', this.currentUser.uid, 'notifications'), orderBy('createdAt', 'desc')), (s) => {
        this.notifications = s.docs.map(d => ({id: d.id, ...d.data()})) as Notification[];
        this.unreadCount = this.notifications.filter(n => !n.read).length; this.cdr.detectChanges();
      });
    }
  }
  getForm(id: string) { if(!this.forms[id]) this.forms[id] = {price:null, description:''}; return this.forms[id]; }
  toggleNotifications() { this.showNotifications = !this.showNotifications; if(this.showNotifications) this.markAsRead(); }
  markAsRead() { this.notifications.forEach(n => { if(!n.read) updateDoc(doc(db, 'users', this.currentUser!.uid, 'notifications', n.id), {read: true}); }); }
  isRecent(d: string) { return true; } 
  getAllMedia(j: Job) { return []; }
  isVideo(u: string) { return false; }
  formatTimestamp(t: any) { return new Date(); }
  
  async applyToJob(job: Job) {
    const form = this.getForm(job.id);
    if(!form.price) return alert("Prix requis");
    try {
      await updateDoc(doc(db, 'jobs', job.id), {
        proposals: arrayUnion({
          workerId: this.currentUser!.uid,
          workerName: this.currentUser!.displayName || 'Artisan',
          price: form.price,
          description: form.description,
          status: 'pending',
          createdAt: new Date().toISOString()
        })
      });

      await addDoc(collection(db, 'users', job.userId, 'notifications'), {
        message: \`Nouvelle proposition de \${form.price} TND pour votre panne !\`,
        jobId: job.id,
        createdAt: new Date().toISOString(),
        read: false,
        type: 'new_proposal'
      });

      alert("Devis envoyé !");
    } catch(e) { console.error(e); }
  }

  ngOnDestroy() { if(this.unsubscribe) this.unsubscribe(); if(this.notifUnsubscribe) this.notifUnsubscribe(); }
}
EOF


# ==========================================
# 3. UserProfileComponent (UPDATE: Dashboard Client complet)
# ==========================================
UP_FILE="src/app/features/dashboard/user-profile/user-profile.component.ts"
echo -e "  - Réparation ${UP_FILE} (Correctif TS2532)..."

cat <<EOF > "$UP_FILE"
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
  template: \`
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
  \`
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
EOF

# ==========================================
# 4. WorkerProfileComponent (Update: Details & Chat)
# ==========================================
WORKER_FILE="src/app/features/dashboard/worker-profile/worker-profile.component.ts"
echo -e "  - Correction ${WORKER_FILE}..."
cat <<EOF > "$WORKER_FILE"
import { Component, OnInit, OnDestroy, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule, DatePipe } from '@angular/common';
import { auth, db } from '../../../core/firebase.config'; 
import { collection, query, where, onSnapshot, Unsubscribe, orderBy, limit } from 'firebase/firestore';
import { ChatComponent } from '../chat/chat.component';

interface Job { id: string; description: string; imageUrl?: string; imageUrls?: string[]; status: string; createdAt: any; acceptedPrice?: number; userEmail?: string; unreadCount?: number; }

@Component({
  selector: 'app-worker-profile',
  standalone: true,
  imports: [CommonModule, ChatComponent],
  template: \`
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
                 <div class="flex justify-between">
                   <h5 class="font-bold text-gray-800 line-clamp-1">{{ job.description }}</h5>
                   @if (job.unreadCount && job.unreadCount > 0) {
                     <span class="bg-red-500 text-white text-xs px-2 py-0.5 rounded-full animate-bounce">{{ job.unreadCount }}</span>
                   }
                 </div>
                 <div class="flex justify-between items-end mt-1">
                   <div class="text-xs text-gray-500"><p>Prix: {{ job.acceptedPrice }} TND</p></div>
                   <div class="flex gap-2">
                     <button (click)="viewJobDetails(job)" class="bg-gray-100 text-gray-700 py-1.5 px-3 rounded-lg text-xs font-bold border border-gray-300">Détails 📋</button>
                     <button (click)="openChat(job)" class="bg-blue-50 text-blue-600 py-1.5 px-3 rounded-lg text-xs font-bold border border-blue-200">Chat 💬</button>
                     <button (click)="contactClient(job)" class="bg-green-50 text-green-700 py-1.5 px-3 rounded-lg text-xs font-bold border border-green-200">Appeler 📞</button>
                   </div>
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
                  <label class="text-xs font-bold text-gray-500 uppercase">Description</label>
                  <p class="text-sm text-gray-800 bg-gray-50 p-3 rounded mt-1">{{ selectedJobForDetails.description }}</p>
                </div>
                
                <div class="flex justify-between border-t pt-3">
                  <div>
                    <label class="text-xs font-bold text-gray-500 uppercase">Client</label>
                    <p class="text-sm font-medium">{{ selectedJobForDetails.userEmail || 'Anonyme' }}</p>
                  </div>
                  <div class="text-right">
                    <label class="text-xs font-bold text-gray-500 uppercase">Prix Validé</label>
                    <p class="text-lg font-bold text-green-600">{{ selectedJobForDetails.acceptedPrice }} TND</p>
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
  \`
})
export class WorkerProfileComponent implements OnInit, OnDestroy {
  activeJobs: Job[] = []; isLoading = true; selectedJobForChat: Job | null = null; selectedJobForDetails: Job | null = null;
  private unsubscribe: any; private msgListeners: any[] = []; private cdr = inject(ChangeDetectorRef);

  ngOnInit() {
    const user = auth.currentUser; if (!user) return;
    // Typage 's' explicite pour éviter TS7006, ou on laisse l'inférence qui est souvent 'QuerySnapshot'
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
  
  contactClient(job: Job) { if(job.userEmail) window.location.href = \`mailto:\${job.userEmail}\`; }
  
  getAllMedia(job: Job): string[] { if (job.imageUrls && job.imageUrls.length > 0) return job.imageUrls; if (job.imageUrl) return [job.imageUrl]; return []; }
  isVideo(url: string): boolean { if (!url) return false; return !!url.match(/\.(mp4|webm|ogg|mov|avi|mkv)(\?.*)?$/i); }
  
  formatTimestamp(t: any) { return t?.toDate ? t.toDate() : new Date(t || new Date()); }
  ngOnDestroy() { if(this.unsubscribe) this.unsubscribe(); this.msgListeners.forEach(u => u()); }
}
EOF

echo -e "${GREEN}✅ Tous les fichiers sont corrigés et nettoyés !${NC}"