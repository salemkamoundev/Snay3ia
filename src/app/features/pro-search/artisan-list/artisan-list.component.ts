import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { collection, query, where, onSnapshot, Firestore } from 'firebase/firestore';
import { db } from '../../../core/firebase.config'; // Importer l'instance Firestore

// Interfaces
interface Artisan {
  id: string;
  name: string;
  specialty: string;
  city: string;
  rating: number; // Ex: Note moyenne
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

  /**
   * Écoute en temps réel la collection 'artisans' de Firestore.
   */
  loadArtisans(): void {
    const artisansCollection = collection(this.firestore, 'artisans');
    // NOTE: Le tri et la pagination peuvent être ajoutés ici pour les grandes listes.

    onSnapshot(artisansCollection, (snapshot) => {
      const artisansData: Artisan[] = [];
      snapshot.forEach(doc => {
        // Le casting 'as Artisan' est simplifié; des vérifications de type strictes sont recommandées.
        artisansData.push({ 
          id: doc.id, 
          ...(doc.data() as Omit<Artisan, 'id'>) 
        });
      });
      this.artisans = artisansData;
      this.isLoading = false;
      console.log(`[ArtisanList] ${this.artisans.length} artisans chargés.`);
    }, (error) => {
      console.error("[ArtisanList] Erreur de chargement des artisans:", error);
      this.isLoading = false;
      // Afficher l'erreur à l'utilisateur si nécessaire
    });
  }
}
