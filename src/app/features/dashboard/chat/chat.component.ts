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
  `
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
      textToSend = `> Réponse à ${this.replyToMessage.senderName}: "${quotedText}"\n\n${textToSend}`;
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
