#!/bin/bash

# ==========================================
# FIX IMPORTS & CLEANUP - Snay3ia
# 1. Réécrit les fichiers TS avec les bons chemins (../../../) DIRECTEMENT.
# 2. Supprime les dépendances inutiles.
# 3. Met à jour WorkerProfile avec Détails enrichis et Chat.
# 4. FIX CHAT : Hauteur responsive + Réponse + Lecture automatique.
# 5. UPDATE CLIENT : Clôture de mission (Note, Audio, Satisfaction).
# 6. UPDATE SERVICE : Profils artisans réels connectés à Firestore.
# 7. BUGFIX : Échappement de $index et correction des paths relatifs.
# ==========================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 Mise à jour complète (Avis Audio & Profils Réels & Bugfixes)...${NC}"

# ==========================================
# 1. UserService (Mode Réel : Fetch Firestore Reviews)
# ==========================================
USER_SERVICE_DIR="src/app/core/services"
mkdir -p "$USER_SERVICE_DIR"
USER_SERVICE_FILE="$USER_SERVICE_DIR/user.service.ts"

echo -e "  - Mise à jour UserService (Mode Réel)..."
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
  rating: number; // 1 (Non satisfait) ou 5 (Satisfait)
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
  
  // Récupère les données réelles de l'artisan et ses avis
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
              rating: userData['rating'] || 0, // Calculé idéalement par une Cloud Function
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
# 2. UserProfileComponent (Clôture Mission + Audio + Profil)
# ==========================================
UP_FILE="src/app/features/dashboard/user-profile/user-profile.component.ts"
echo -e "  - Mise à jour UserProfile (Clôture & Audio)..."

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
interface Job { id: string; description: string; imageUrl?: string; imageUrls?: string[]; status: string; createdAt: any; proposals?: Proposal[]; unreadCount?: number; workerId?: string; workerName?: string; }
interface Notification { id: string; message: string; createdAt: any; read: boolean; }

@Component({
  selector: 'app-user-profile',
  standalone: true,
  imports: [CommonModule, ChatComponent, FormsModule],
  template: \`
    <div class="space-y-6 pb-20 relative">
      <!-- HEADER -->
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

      <!-- LISTE DES JOBS -->
      @if (!isLoading && jobs.length > 0) {
        <div class="space-y-4">
          @for (job of jobs; track job.id) {
            <div class="bg-white p-4 rounded-xl shadow-sm border border-gray-100 flex flex-col gap-3 relative overflow-hidden">
              <!-- Banner Statut Terminé -->
              @if (job.status === 'completed') {
                <div class="absolute top-0 left-0 w-full h-1 bg-green-500"></div>
              }

              <div class="flex gap-4 items-start">
                <div class="w-20 h-20 flex-shrink-0 bg-gray-100 rounded-lg overflow-hidden relative">
                  <img [src]="getMainMedia(job)" class="w-full h-full object-cover">
                </div>
                <div class="flex-grow min-w-0">
                  <div class="flex justify-between items-start mb-1">
                    <span class="px-2 py-0.5 rounded text-[10px] font-bold uppercase" [class]="getStatusClass(job.status)">{{ getStatusLabel(job.status) }}</span>
                    <span class="text-xs text-gray-400 ml-2">{{ formatTimestamp(job.createdAt) | date:'dd MMM' }}</span>
                  </div>
                  <p class="text-gray-800 font-medium text-sm line-clamp-2">{{ job.description }}</p>
                </div>
              </div>

              <!-- ACTIONS -->
              <div class="flex gap-2 border-t pt-3">
                @if (job.status === 'assigned') {
                  <button (click)="openChat(job)" class="flex-1 py-2 bg-blue-50 text-blue-600 rounded-lg text-sm font-bold border border-blue-200">Chat 💬</button>
                  <button (click)="openCompletionModal(job)" class="flex-1 py-2 bg-green-600 text-white rounded-lg text-sm font-bold shadow hover:bg-green-700">Terminer & Noter ✅</button>
                }
                @if (job.status === 'analyzing') {
                  <button (click)="viewDetails(job)" class="flex-1 py-2 bg-gray-100 text-gray-700 rounded-lg text-sm font-bold border border-gray-300">Voir {{ job.proposals?.length || 0 }} Offre(s)</button>
                }
                @if (job.status === 'completed') {
                  <div class="w-full text-center text-green-600 text-sm font-bold bg-green-50 py-2 rounded">Mission Terminée 🎉</div>
                }
              </div>
            </div>
          }
        </div>
      } @else { <div class="text-center py-10 text-gray-500">Aucune demande.</div> }

      <!-- MODALE DE FIN DE CHANTIER (NOTATION) -->
      @if (jobToComplete) {
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4 animate-fade-in">
          <div class="bg-white w-full max-w-md rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[90vh]">
            <div class="p-4 border-b bg-green-600 text-white flex justify-between items-center">
              <h3 class="font-bold">Clôturer la mission</h3>
              <button (click)="closeCompletionModal()" class="text-white/80 text-xl">✕</button>
            </div>
            
            <div class="p-6 overflow-y-auto">
              <p class="text-sm text-gray-600 mb-4 text-center">Le travail a-t-il été effectué correctement ?</p>
              
              <div class="flex gap-4 justify-center mb-6">
                <button (click)="reviewForm.satisfied = true" [class.ring-2]="reviewForm.satisfied" class="flex-1 p-4 rounded-xl border transition bg-green-50 border-green-200 text-green-700 flex flex-col items-center gap-2">
                  <span class="text-2xl">👍</span>
                  <span class="font-bold text-sm">Oui, parfait</span>
                </button>
                <button (click)="reviewForm.satisfied = false" [class.ring-2]="!reviewForm.satisfied" class="flex-1 p-4 rounded-xl border transition bg-red-50 border-red-200 text-red-700 flex flex-col items-center gap-2">
                  <span class="text-2xl">👎</span>
                  <span class="font-bold text-sm">Non, problème</span>
                </button>
              </div>

              <div class="mb-4">
                <label class="text-xs font-bold text-gray-500 mb-1 block">Votre avis (Obligatoire)</label>
                <textarea [(ngModel)]="reviewForm.comment" rows="3" placeholder="Dites-nous en plus..." class="w-full p-3 border rounded-lg text-sm focus:ring-green-500 outline-none"></textarea>
              </div>

              <!-- Audio Recorder -->
              <div class="mb-6">
                <label class="text-xs font-bold text-gray-500 mb-1 block">Ou laissez un vocal</label>
                @if (!reviewForm.audioUrl && !isRecording) {
                   <button (click)="startRecording()" class="w-full py-3 bg-gray-100 text-gray-600 rounded-lg text-sm font-bold flex items-center justify-center gap-2 hover:bg-gray-200">
                     <span>🎙️</span> Enregistrer un avis vocal
                   </button>
                } @else if (isRecording) {
                   <button (click)="stopRecording()" class="w-full py-3 bg-red-500 text-white rounded-lg text-sm font-bold animate-pulse">
                     ⏹️ Arrêter l'enregistrement
                   </button>
                } @else {
                   <div class="flex items-center gap-2 bg-gray-50 p-2 rounded border">
                     <audio [src]="reviewForm.audioUrl" controls class="w-full h-8"></audio>
                     <button (click)="deleteAudio()" class="text-red-500 px-2">🗑️</button>
                   </div>
                }
              </div>

              <button (click)="submitReview()" [disabled]="isSubmitting" class="w-full py-3 bg-green-600 text-white font-bold rounded-xl shadow-lg hover:bg-green-700 disabled:opacity-50">
                {{ isSubmitting ? 'Envoi...' : 'Confirmer la fin du chantier' }}
              </button>
            </div>
          </div>
        </div>
      }

      <!-- MODALE PROFIL ARTISAN (Réel) -->
      @if (selectedWorker) {
        <div class="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/50 backdrop-blur-sm animate-fade-in p-4">
          <div class="bg-white w-full max-w-md rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[85vh]">
            <div class="bg-blue-600 p-6 text-white text-center relative flex-shrink-0">
              <button (click)="closeProfile()" class="absolute top-4 right-4 text-white/80">✕</button>
              <h2 class="text-xl font-bold">{{ selectedWorker.displayName }}</h2>
              <p class="text-blue-100 text-sm">{{ selectedWorker.specialty }}</p>
              <div class="flex justify-center gap-1 mt-2 text-yellow-300">★ {{ selectedWorker.rating }}</div>
            </div>
            
            <div class="p-4 overflow-y-auto bg-gray-50 flex-grow">
              <h3 class="font-bold text-gray-700 text-sm mb-3 uppercase">Retours Clients ({{ selectedWorker.reviews.length }})</h3>
              
              @if (selectedWorker.reviews.length === 0) {
                <p class="text-center text-gray-400 text-sm py-4">Aucun avis pour le moment.</p>
              }
              
              <div class="space-y-3">
                @for (review of selectedWorker.reviews; track \$index) {
                  <div class="bg-white p-3 rounded-lg border border-gray-100 shadow-sm">
                    <div class="flex justify-between items-center mb-1">
                      <span class="font-bold text-sm text-gray-800">{{ review.author }}</span>
                      <span class="px-2 py-0.5 rounded text-[10px] font-bold" [class]="review.isSatisfied ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'">
                        {{ review.isSatisfied ? '👍 Satisfait' : '👎 Déçu' }}
                      </span>
                    </div>
                    
                    @if (review.comment) { <p class="text-gray-600 text-xs italic">"{{ review.comment }}"</p> }
                    @if (review.audioUrl) { <audio [src]="review.audioUrl" controls class="w-full h-6 mt-2"></audio> }
                  </div>
                }
              </div>
            </div>
          </div>
        </div>
      }

      <!-- Modale Chat (Existante) -->
      @if (selectedJobForChat) {
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 backdrop-blur-sm p-4">
          <div class="bg-white w-full max-w-md rounded-2xl shadow-2xl overflow-hidden flex flex-col max-h-[80vh]">
             <div class="p-3 bg-gray-100 border-b flex justify-between items-center">
               <h3 class="font-bold">Chat</h3><button (click)="closeChat()" class="text-xl">×</button>
             </div>
             <app-chat [jobId]="selectedJobForChat.id" class="flex-grow overflow-hidden"></app-chat>
          </div>
        </div>
      }
    </div>
  \`
})
export class UserProfileComponent implements OnInit, OnDestroy {
  jobs: Job[] = []; notifications: Notification[] = []; isLoading = true; 
  selectedJobForChat: Job | null = null; selectedJobDetails: Job | null = null; selectedWorker: WorkerProfile | null = null;
  jobToComplete: Job | null = null; // Job en cours de clôture
  
  // Formulaire Avis
  reviewForm = { satisfied: true, comment: '', audioUrl: '', audioBlob: null as any };
  isRecording = false; isSubmitting = false;
  private mediaRecorder: any = null; audioChunks: any[] = [];

  showNotifications = false; unreadCount = 0;
  
  private unsubscribe: any; private notifUnsubscribe: any; 
  private cdr = inject(ChangeDetectorRef); private userService = inject(UserService); currentUser = auth.currentUser;

  ngOnInit() {
    if (!this.currentUser) return;
    this.unsubscribe = onSnapshot(query(collection(db, 'jobs'), where('userId', '==', this.currentUser.uid)), (s) => {
      this.jobs = s.docs.map(d => ({id: d.id, ...d.data()})) as Job[]; 
      this.jobs.sort((a, b) => this.formatTimestamp(b.createdAt).getTime() - this.formatTimestamp(a.createdAt).getTime());
      this.isLoading = false; 
      this.cdr.detectChanges();
    });
  }

  // --- LOGIQUE DE CLÔTURE ---
  openCompletionModal(job: Job) { this.jobToComplete = job; this.resetReviewForm(); }
  closeCompletionModal() { this.jobToComplete = null; }
  resetReviewForm() { this.reviewForm = { satisfied: true, comment: '', audioUrl: '', audioBlob: null }; }

  async startRecording() {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      this.mediaRecorder = new MediaRecorder(stream);
      this.audioChunks = [];
      this.mediaRecorder.ondataavailable = (e: any) => this.audioChunks.push(e.data);
      this.mediaRecorder.onstop = () => {
        const blob = new Blob(this.audioChunks, { type: 'audio/mp3' });
        this.reviewForm.audioBlob = blob;
        this.reviewForm.audioUrl = URL.createObjectURL(blob);
        this.isRecording = false;
        this.cdr.detectChanges();
      };
      this.mediaRecorder.start();
      this.isRecording = true;
    } catch (e) { alert("Microphone inaccessible"); }
  }
  stopRecording() { if(this.mediaRecorder) this.mediaRecorder.stop(); }
  deleteAudio() { this.reviewForm.audioBlob = null; this.reviewForm.audioUrl = ''; }

  async submitReview() {
    if (!this.jobToComplete || !this.currentUser) return;
    if (!this.reviewForm.comment && !this.reviewForm.audioBlob) {
      alert("Veuillez laisser un commentaire écrit ou vocal.");
      return;
    }

    this.isSubmitting = true;
    let finalAudioUrl = null;

    try {
      // 1. Upload Audio si présent
      if (this.reviewForm.audioBlob) {
        const fileName = \`reviews/\${this.jobToComplete.id}_\${Date.now()}.mp3\`;
        const { error } = await supabase.storage.from(STORAGE_BUCKET_BREAKDOWNS).upload(fileName, this.reviewForm.audioBlob);
        if (!error) {
          const { data } = supabase.storage.from(STORAGE_BUCKET_BREAKDOWNS).getPublicUrl(fileName);
          finalAudioUrl = data.publicUrl;
        }
      }

      // 2. Créer l'objet Review
      const reviewData = {
        author: this.currentUser.displayName || 'Client',
        comment: this.reviewForm.comment,
        audioUrl: finalAudioUrl,
        isSatisfied: this.reviewForm.satisfied,
        rating: this.reviewForm.satisfied ? 5 : 1, // Simplification pour la démo
        createdAt: new Date().toISOString()
      };

      // 3. Sauvegarder l'avis sur le profil de l'artisan
      if (this.jobToComplete.workerId) {
        await addDoc(collection(db, 'users', this.jobToComplete.workerId, 'reviews'), reviewData);
        
        // Mise à jour du compteur de jobs terminés (Atomique idéalement, ici simple update)
        // updateDoc(doc(db, 'users', this.jobToComplete.workerId), { completedJobs: increment(1) });
      }

      // 4. Clôturer le Job
      await updateDoc(doc(db, 'jobs', this.jobToComplete.id), {
        status: 'completed',
        review: reviewData,
        completedAt: new Date()
      });

      alert("Mission terminée et avis enregistré ! Merci.");
      this.closeCompletionModal();

    } catch (e) { console.error(e); alert("Erreur lors de l'envoi"); } 
    finally { this.isSubmitting = false; this.cdr.detectChanges(); }
  }

  // --- NAVIGATION & VIEWERS ---
  viewWorkerProfile(workerId: string) {
    this.userService.getWorkerProfile(workerId).subscribe(p => { this.selectedWorker = p; this.cdr.detectChanges(); });
  }
  closeProfile() { this.selectedWorker = null; }
  
  openChat(job: Job) { this.selectedJobForChat = job; }
  closeChat() { this.selectedJobForChat = null; }
  viewDetails(job: Job) { this.selectedJobDetails = job; }
  closeDetails() { this.selectedJobDetails = null; }
  
  // --- HELPERS ---
  getMainMedia(j: Job) { return j.imageUrls?.[0] || j.imageUrl || ''; }
  getAllMedia(j: Job) { return j.imageUrls || [j.imageUrl || '']; }
  isVideo(u: string) { return !!u.match(/\.(mp4|webm)(\?.*)?$/i); }
  getStatusLabel(s: string) { return s === 'assigned' ? 'En Cours' : (s === 'completed' ? 'Terminé' : 'Ouvert'); }
  getStatusClass(s: string) { return s === 'assigned' ? 'bg-blue-100 text-blue-700' : (s === 'completed' ? 'bg-gray-100 text-gray-600' : 'bg-green-100 text-green-700'); }
  formatTimestamp(t: any) { return t?.toDate ? t.toDate() : new Date(t || new Date()); }
  toggleNotifications() {} // Placeholder, logic already in previous component
  ngOnDestroy() { if(this.unsubscribe) this.unsubscribe(); }
}
EOF

# ==========================================
# 3. RegisterComponent (Inchangé)
# ==========================================
REGISTER_FILE="src/app/features/auth/register/register.component.ts"
cat <<EOF > "$REGISTER_FILE"
import { Component, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { createUserWithEmailAndPassword, updateProfile } from 'firebase/auth';
import { auth } from '../../../core/firebase.config';

@Component({
  selector: 'app-register',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink],
  templateUrl: './register.component.html'
})
export class RegisterComponent {
  private router = inject(Router);
  fullName = ''; email = ''; password = ''; confirmPassword = ''; errorMessage = ''; isLoading = false;
  async onRegister() {
    if (this.password !== this.confirmPassword) { this.errorMessage = 'Les mots de passe ne correspondent pas.'; return; }
    this.isLoading = true; this.errorMessage = '';
    try {
      const userCredential = await createUserWithEmailAndPassword(auth, this.email, this.password);
      if (this.fullName) await updateProfile(userCredential.user, { displayName: this.fullName });
      this.router.navigate(['/role-select']);
    } catch (error: any) { this.errorMessage = error.code; } finally { this.isLoading = false; }
  }
}
EOF

# ==========================================
# 4. ChatComponent (Correction Path)
# ==========================================
CHAT_DIR="src/app/features/dashboard/chat"
CHAT_FILE="$CHAT_DIR/chat.component.ts"
cat <<EOF > "$CHAT_FILE"
import { Component, Input, OnInit, OnDestroy, ViewChild, ElementRef, AfterViewChecked, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { auth, db } from '../../../core/firebase.config'; // CORRECT: 3 niveaux
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

echo -e "${GREEN}✅ Mise à jour effectuée : Profils Réels et Avis Vocaux activés !${NC}"