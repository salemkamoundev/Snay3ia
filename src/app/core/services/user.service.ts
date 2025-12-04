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
