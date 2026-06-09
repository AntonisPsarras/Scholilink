import 'package:firebase_auth/firebase_auth.dart';

class FirebaseErrorHandler {
  static String getMessage(dynamic error, String lang) {
    if (error is FirebaseAuthException) {
      if (lang == 'el') {
        switch (error.code) {
          case 'invalid-email':
            return 'Μη έγκυρη μορφή email.';
          case 'user-disabled':
            return 'Αυτός ο λογαριασμός έχει απενεργοποιηθεί.';
          case 'user-not-found':
            return 'Δεν βρέθηκε χρήστης με αυτό το email.';
          case 'wrong-password':
            return 'Λάθος κωδικός πρόσβασης.';
          case 'email-already-in-use':
            return 'Το email χρησιμοποιείται ήδη από άλλον λογαριασμό.';
          case 'operation-not-allowed':
            return 'Αυτή η λειτουργία δεν επιτρέπεται.';
          case 'weak-password':
            return 'Ο κωδικός πρόσβασης είναι πολύ αδύναμος.';
          case 'invalid-credential':
            return 'Λάθος email ή κωδικός πρόσβασης.';
          case 'network-request-failed':
            return 'Σφάλμα δικτύου. Ελέγξτε τη σύνδεσή σας στο διαδίκτυο.';
          case 'too-many-requests':
            return 'Πάρα πολλές προσπάθειες. Δοκιμάστε ξανά αργότερα.';
          default:
            return 'Προέκυψε σφάλμα ταυτοποίησης (${error.code}).';
        }
      } else {
        switch (error.code) {
          case 'invalid-email':
            return 'Invalid email format.';
          case 'user-disabled':
            return 'This account has been disabled.';
          case 'user-not-found':
            return 'No user found with this email.';
          case 'wrong-password':
            return 'Incorrect password.';
          case 'email-already-in-use':
            return 'Email is already in use by another account.';
          case 'operation-not-allowed':
            return 'This operation is not allowed.';
          case 'weak-password':
            return 'The password is too weak.';
          case 'invalid-credential':
            return 'Incorrect email or password.';
          case 'network-request-failed':
            return 'Network error. Please check your internet connection.';
          case 'too-many-requests':
            return 'Too many attempts. Please try again later.';
          default:
            return 'Authentication error occurred (${error.code}).';
        }
      }
    } else if (error is StateError && error.message == 'upload_too_large') {
      return lang == 'el'
          ? 'Το αρχείο είναι πολύ μεγάλο (μέγιστο 10 MB).'
          : 'The file is too large (10 MB maximum).';
    } else if (error is FirebaseException) {
      if (error.plugin == 'firebase_storage' && error.code == 'unauthorized') {
        return lang == 'el'
            ? 'Δεν επιτρέπεται η αποστολή αρχείου. Βεβαιωθείτε ότι είστε συνδεδεμένοι και δοκιμάστε ξανά.'
            : 'File upload was denied. Make sure you are signed in and try again.';
      }
      if (lang == 'el') {
        switch (error.code) {
          case 'permission-denied':
            return 'Δεν έχετε δικαίωμα πρόσβασης σε αυτά τα δεδομένα.';
          case 'unavailable':
            return 'Η υπηρεσία δεν είναι διαθέσιμη αυτή τη στιγμή.';
          case 'not-found':
            return 'Το στοιχείο δεν βρέθηκε.';
          case 'already-exists':
            return 'Το στοιχείο υπάρχει ήδη.';
          default:
            return 'Προέκυψε σφάλμα βάσης δεδομένων (${error.code}).';
        }
      } else {
        switch (error.code) {
          case 'permission-denied':
            return 'You do not have permission to access this data.';
          case 'unavailable':
            return 'The service is currently unavailable.';
          case 'not-found':
            return 'The requested item was not found.';
          case 'already-exists':
            return 'The item already exists.';
          default:
            return 'A database error occurred (${error.code}).';
        }
      }
    }

    if (lang == 'el') {
      return 'Προέκυψε ένα άγνωστο σφάλμα.';
    }
    return 'An unknown error occurred.';
  }
}
