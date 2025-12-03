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
  template: `
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
  `
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
        message: `Nouvelle proposition de ${form.price} TND pour votre panne !`,
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
