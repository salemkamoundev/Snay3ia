import { Component, Input, OnInit, OnDestroy, ViewChild, ElementRef, AfterViewChecked, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { auth, db } from '../../../core/firebase.config'; 
import { collection, query, orderBy, addDoc, onSnapshot, serverTimestamp, updateDoc, doc } from 'firebase/firestore';

@Component({
  selector: 'app-chat',
  standalone: true,
  imports: [CommonModule, FormsModule],
  template: `
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
  `
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
