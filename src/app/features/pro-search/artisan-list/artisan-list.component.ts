import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { collection, query, where, onSnapshot, Firestore } from 'firebase/firestore';
import { db } from '../../../core/firebase.config'; // CORRECT: 3 niveaux

interface Artisan {
  id: string;
  name: string;
  specialty: string;
  city: string;
  rating: number;
}

@Component({
  selector: 'app-artisan-list',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './artisan-list.component.html',
  styleUrl: './artisan-list.component.scss',
})
export class ArtisanListComponent implements OnInit {
  artisans: Artisan[] = [];
  isLoading = true;
  private firestore: Firestore = db;

  ngOnInit(): void {
    this.loadArtisans();
  }

  loadArtisans(): void {
    const artisansCollection = collection(this.firestore, 'artisans');
    onSnapshot(artisansCollection, (snapshot) => {
      const artisansData: Artisan[] = [];
      snapshot.forEach(doc => {
        artisansData.push({ 
          id: doc.id, 
          ...(doc.data() as Omit<Artisan, 'id'>) 
        });
      });
      this.artisans = artisansData;
      this.isLoading = false;
    }, (error) => {
      console.error("[ArtisanList] Erreur de chargement des artisans:", error);
      this.isLoading = false;
    });
  }
}
