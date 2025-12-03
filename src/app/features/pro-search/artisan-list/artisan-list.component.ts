import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { collection, query, where, onSnapshot, Firestore } from 'firebase/firestore';
import { db } from '../../../core/firebase.config';

interface Artisan { id: string; name: string; specialty: string; city: string; rating: number; }
@Component({
  selector: 'app-artisan-list',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './artisan-list.component.html',
  styleUrl: './artisan-list.component.scss',
})
export class ArtisanListComponent implements OnInit {
  artisans: Artisan[] = []; isLoading = true; private firestore = db;
  ngOnInit() { this.loadArtisans(); }
  loadArtisans() {
    onSnapshot(collection(this.firestore, 'artisans'), (snapshot) => {
      this.artisans = snapshot.docs.map(doc => ({ id: doc.id, ...(doc.data() as Omit<Artisan, 'id'>) }));
      this.isLoading = false;
    });
  }
}
