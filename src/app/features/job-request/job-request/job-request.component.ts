import { Component, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Sannay3iService } from '../../../core/services/sannay3i.service';

@Component({
  selector: 'app-job-request',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './job-request.component.html',
  styleUrl: './job-request.component.scss',
})
export class JobRequestComponent {
  private sannay3iService = inject(Sannay3iService);
  private cdr = inject(ChangeDetectorRef); // Injection pour forcer la mise à jour

  // Form data
  jobDescription: string = '';
  jobFile: File | null = null;
  
  // State
  isUploading = false;
  isSuccess = false; 
  uploadMessage = '';
  jobId: string | null = null;

  onFileSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    if (input.files && input.files.length > 0) {
      this.jobFile = input.files[0];
      this.uploadMessage = `Fichier prêt : ${this.jobFile.name}`;
    }
  }

  async submitJobRequest(): Promise<void> {
    if (!this.jobDescription || !this.jobFile) {
      this.uploadMessage = 'Veuillez remplir la description et ajouter une photo.';
      return;
    }

    this.isUploading = true;
    this.uploadMessage = 'Envoi de la demande en cours...';
    
    try {
      const response = await this.sannay3iService.createJob(this.jobDescription, this.jobFile);
      
      if (!response) {
        throw new Error('Le service n\'a pas retourné de confirmation.');
      }

      const newJobId = typeof response === 'string' ? response : (response as any).id;
      this.jobId = newJobId;
      console.log('Composant: Demande créée avec succès, ID:', this.jobId);
      
      // Mise à jour de l'état
      this.isSuccess = true; 
      this.isUploading = false; 
      this.jobDescription = '';
      this.jobFile = null;
      this.uploadMessage = '';

      // FORCE LA MISE À JOUR DE LA VUE
      // C'est crucial quand on utilise async/await avec des callbacks externes
      this.cdr.detectChanges(); 

    } catch (error: any) {
      this.isUploading = false;
      this.isSuccess = false;
      this.uploadMessage = `Erreur : ${error.message || 'Erreur inconnue'}`;
      console.error('Erreur dans submitJobRequest:', error);
      this.cdr.detectChanges(); // On force aussi l'affichage de l'erreur
    }
  }

  resetView(): void {
    this.isSuccess = false;
    this.uploadMessage = '';
    this.jobId = null;
    this.cdr.detectChanges();
  }
}
