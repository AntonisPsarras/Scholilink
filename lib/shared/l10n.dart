import 'package:flutter/material.dart';

class S {
  final String lang;
  S(this.lang);

  static S of(BuildContext context, String lang) {
    return S(lang);
  }

  // --- Common ---
  String get appTitle => lang == 'el' ? 'ScholiLink' : 'ScholiLink';
  String get menuHome => lang == 'el' ? 'Κεντρική' : 'Home';
  String get menuHomework => lang == 'el' ? 'Εργασίες' : 'Homework';
  String get menuSchedule => lang == 'el' ? 'Πρόγραμμα' : 'Schedule';
  String get menuMessages => lang == 'el' ? 'Μηνύματα' : 'Messages';
  String get menuProfile => lang == 'el' ? 'Προφίλ' : 'Profile';
  String get welcome => lang == 'el' ? 'Καλώς ήρθατε!' : 'Welcome!';
  String get loginWelcomeTitle =>
      lang == 'el' ? 'Καλώς ήρθατε!' : 'Welcome!';
  String get loginWelcomeSubtitle => lang == 'el'
      ? 'Καλώς ήρθατε στο ScholiLink'
      : 'Welcome to ScholiLink';
  String get logout => lang == 'el' ? 'Αποσύνδεση' : 'Logout';

  // --- Auth & Onboarding ---
  String get fullName => lang == 'el' ? 'Ονοματεπώνυμο' : 'Full Name';
  String get email => lang == 'el' ? 'Email' : 'Email';
  String get password => lang == 'el' ? 'Κωδικός' : 'Password';
  String get createAccount =>
      lang == 'el' ? 'Δημιουργία Λογαριασμού' : 'Create Account';
  String get languageSelect => lang == 'el' ? 'Γλώσσα' : 'Language';
  String get registerFor =>
      lang == 'el' ? 'Εγγραφή στο ScholiLink' : 'Register for ScholiLink';
  String get selectGrade => lang == 'el'
      ? 'Παρακαλώ επιλέξτε την τάξη σας'
      : 'Please select your grade';
  String get selectDirection => lang == 'el'
      ? 'Επιλέξτε Προσανατολισμό / Κατεύθυνση'
      : 'Select Direction';
  String get saveAndContinue =>
      lang == 'el' ? 'Αποθήκευση & Συνέχεια' : 'Save & Continue';
  String get tutoringQuery => lang == 'el'
      ? 'Ποια μαθήματα κάνετε ιδιαίτερα;'
      : 'Which subjects do you have tutoring for?';
  String get onboardingSubtext => lang == 'el'
      ? 'Ας προσαρμόσουμε το dashboard για τις σχολικές σου ανάγκες.'
      : 'Let\'s customize your dashboard for your school needs.';
  String get login => lang == 'el' ? 'Σύνδεση' : 'Login';
  String get noAccount =>
      lang == 'el' ? 'Δεν έχετε λογαριασμό; Εγγραφή' : 'No account? Register';
  String get haveAccount =>
      lang == 'el' ? 'Έχετε ήδη λογαριασμό; Σύνδεση' : 'Have an account? Login';

  // --- Dashboard ---
  String get goodMorning => lang == 'el' ? 'Καλημέρα' : 'Good morning';
  String get nextClass => lang == 'el' ? 'Επόμενο Μάθημα' : 'Next Class';
  String get readinessScore =>
      lang == 'el' ? 'Βαθμός Ετοιμότητας' : 'Readiness Score';
  String get homeworkStream =>
      lang == 'el' ? 'Ροή Εργασιών' : 'Homework Stream';
  String get viewAll => lang == 'el' ? 'Προβολή Όλων' : 'View All';
  String get mySubjects => lang == 'el' ? 'Τα Μαθήματά μου' : 'My Subjects';
  String get upcomingExams =>
      lang == 'el' ? 'Προσεχείς Εξετάσεις' : 'Upcoming Exams';
  String get manageSchedule =>
      lang == 'el' ? 'Διαχείριση Προγράμματος' : 'Manage Schedule';
  String get addExam => lang == 'el' ? 'Προσθήκη Εξέτασης' : 'Add Exam';
  String get testKnowledge =>
      lang == 'el' ? 'Έλεγχος Γνώσεων' : 'Test Knowledge';
  String get readinessTooltip => lang == 'el'
      ? 'Ο βαθμός ετοιμότητας εμφανίζεται αφού κάνετε έναν έλεγχο γνώσεων.'
      : 'Readiness score appears after you test your knowledge.';

  // --- Profile ---
  String get myProfile => lang == 'el' ? 'Το Προφίλ μου' : 'My Profile';
  String get grade => lang == 'el' ? 'Τάξη' : 'Grade';
  String get subjects => lang == 'el' ? 'Μαθήματα' : 'Subjects';
  String get absences => lang == 'el' ? 'Απουσίες' : 'Absences';
  String get tutoring => lang == 'el' ? 'Ιδιαίτερα' : 'Tutoring';

  // --- Schedule Editor ---
  String get editSchedule =>
      lang == 'el' ? 'Επεξεργασία Προγράμματος' : 'Edit Schedule';
  String get addClass => lang == 'el' ? 'Προσθήκη Μαθήματος' : 'Add Class';
  String get subject => lang == 'el' ? 'Μάθημα' : 'Subject';
  String get time => lang == 'el' ? 'Ώρα' : 'Time';
  String get room => lang == 'el' ? 'Αίθουσα' : 'Room';
  String get saveSchedule =>
      lang == 'el' ? 'Αποθήκευση Προγράμματος' : 'Save Schedule';
  String get day => lang == 'el' ? 'Ημέρα' : 'Day';
  // Schedule hour slots
  String hourLabel(int n) => lang == 'el' ? '$nη ώρα' : 'Period $n';
  String get emptySlot => lang == 'el' ? 'Κενό' : 'Empty';
  String get tapToSetSubject =>
      lang == 'el' ? 'Πατήστε για μάθημα' : 'Tap to set subject';
  String get permanentSchedule =>
      lang == 'el' ? 'Μόνιμο Πρόγραμμα' : 'Permanent Schedule';
  String get temporarySchedule =>
      lang == 'el' ? 'Προσωρινό Πρόγραμμα' : 'Temporary Schedule';
  String get createTemporary =>
      lang == 'el' ? 'Δημιουργία Προσωρινού' : 'Create Temporary';
  String get expiresOn => lang == 'el' ? 'Λήγει στις' : 'Expires on';
  String get scheduleLabel => lang == 'el' ? 'Ετικέτα' : 'Label';
  String get activeTemporary =>
      lang == 'el' ? 'Ενεργό Προσωρινό Πρόγραμμα' : 'Active Temporary Schedule';
  String get expired => lang == 'el' ? 'Έληξε' : 'Expired';
  String get noTemporarySchedules => lang == 'el'
      ? 'Δεν υπάρχουν προσωρινά προγράμματα.'
      : 'No temporary schedules.';
  String get autoDueDate =>
      lang == 'el' ? 'Αυτόματη ημερομηνία' : 'Auto due date';
  String get dueDateOptional =>
      lang == 'el' ? 'Ημ/νία (προαιρετική)' : 'Due date (optional)';
  String get dueDateRequiredForProject => lang == 'el'
      ? 'Ημ/νία (υποχρεωτική για project)'
      : 'Due date (required for projects)';
  String get pickDueDateForProject => lang == 'el'
      ? 'Επίλεξε ημερομηνία παράδοσης για εργασία τύπου project.'
      : 'Pick a due date for project homework.';
  String get homeworkDeleted =>
      lang == 'el' ? 'Η εργασία διαγράφηκε.' : 'Homework deleted.';
  String get homeworkDeleteFailed => lang == 'el'
      ? 'Αποτυχία διαγραφής. Δοκίμασε ξανά.'
      : 'Could not delete homework. Please try again.';
  String get homeworkSaveFailed => lang == 'el'
      ? 'Αποτυχία αποθήκευσης εργασίας. Δοκίμασε ξανά.'
      : 'Could not save homework. Please try again.';
  String get clearSlot => lang == 'el' ? 'Καθαρισμός' : 'Clear';
  // Convenience features
  String get rememberMe => lang == 'el' ? 'Να με θυμάσαι' : 'Remember me';
  String get manageAbsences =>
      lang == 'el' ? 'Διαχείριση Απουσιών' : 'Manage Absences';
  String get absenceCount =>
      lang == 'el' ? 'Αριθμός απουσιών' : 'Absence count';
  String get tutoringHour => lang == 'el' ? 'Ιδιαίτερο' : 'Tutoring';
  String get addTutoring =>
      lang == 'el' ? 'Προσθήκη Ιδιαίτερου' : 'Add Tutoring';
  String get selectTime => lang == 'el' ? 'Επιλογή Ώρας' : 'Select Time';

  // --- Days of Week ---
  String get monday => lang == 'el' ? 'Δευτέρα' : 'Monday';
  String get tuesday => lang == 'el' ? 'Τρίτη' : 'Tuesday';
  String get wednesday => lang == 'el' ? 'Τετάρτη' : 'Wednesday';
  String get thursday => lang == 'el' ? 'Πέμπτη' : 'Thursday';
  String get friday => lang == 'el' ? 'Παρασκευή' : 'Friday';
  String get saturday => lang == 'el' ? 'Σάββατο' : 'Saturday';
  String get sunday => lang == 'el' ? 'Κυριακή' : 'Sunday';
  String get completeSetup =>
      lang == 'el' ? 'Ολοκλήρωση Ρύθμισης' : 'Complete Setup';
  String get general => lang == 'el' ? 'Γενικά' : 'General';
  String get pleaseLogIn =>
      lang == 'el' ? 'Παρακαλώ συνδεθείτε' : 'Please log in';
  String get loading => lang == 'el' ? 'Φόρτωση...' : 'Loading...';
  String get error => lang == 'el' ? 'Σφάλμα' : 'Error';

  // --- Classroom ---
  String get classroom => lang == 'el' ? 'Τάξη' : 'Classroom';
  String get createClassroom =>
      lang == 'el' ? 'Δημιουργία Τάξης' : 'Create Classroom';
  String get createTooltip => lang == 'el' ? 'Δημιουργία' : 'Create';
  String get joinClassroom =>
      lang == 'el' ? 'Είσοδος σε Τάξη' : 'Join Classroom';
  String get classroomName => lang == 'el' ? 'Όνομα Τάξης' : 'Classroom Name';
  String get inviteCode => lang == 'el' ? 'Κωδικός Πρόσκλησης' : 'Invite Code';
  String get inviteCodeCopied =>
      lang == 'el' ? 'Ο κωδικός αντιγράφηκε!' : 'Invite code copied!';
  String get invalidCode =>
      lang == 'el' ? 'Μη έγκυρος κωδικός πρόσκλησης.' : 'Invalid invite code.';
  String get members => lang == 'el' ? 'μέλη' : 'members';
  String get noClassroomYet => lang == 'el'
      ? 'Δεν έχεις τάξη ακόμα.\nΔημιούργησε μία ή μπες με κωδικό!'
      : 'You don\'t have a classroom yet.\nCreate one or join with a code!';
  String get noHomeworkYet =>
      lang == 'el' ? 'Δεν υπάρχουν εργασίες ακόμα.' : 'No homework posted yet.';
  String get shareToClass =>
      lang == 'el' ? 'Κοινοποίηση στην Τάξη' : 'Share to Class';
  String get homeworkContent =>
      lang == 'el' ? 'Περιγραφή Εργασίας' : 'Homework Content';
  String get cancel => lang == 'el' ? 'Ακύρωση' : 'Cancel';
  String get post => lang == 'el' ? 'Ανάρτηση' : 'Post';
  String get verify => lang == 'el' ? 'Επαλήθευση' : 'Verify';
  String get official => lang == 'el' ? 'Επίσημο' : 'Official';

  // --- Friends & Social ---
  String get friends => lang == 'el' ? 'Φίλοι' : 'Friends';
  String get addFriend => lang == 'el' ? 'Προσθήκη Φίλου' : 'Add Friend';
  String get friendUidHint =>
      lang == 'el' ? 'Αναζήτηση με όνομα ή email' : 'Search by name or email';
  String get requestSent =>
      lang == 'el' ? 'Το αίτημα φιλίας στάλθηκε!' : 'Friend request sent!';
  String get requestFailed => lang == 'el'
      ? 'Αποτυχία αποστολής αιτήματος.'
      : 'Failed to send request.';
  String get pendingRequests =>
      lang == 'el' ? 'Εκκρεμή Αιτήματα' : 'Pending Requests';
  String get noFriendsYet =>
      lang == 'el' ? 'Δεν έχεις φίλους ακόμα.' : 'No friends yet.';
  String get shareGrades =>
      lang == 'el' ? 'Κοινοποίηση Βαθμών' : 'Share Grades';
  String get shareGradesDesc => lang == 'el'
      ? 'Επιτρέπει στους φίλους σου να βλέπουν τους βαθμούς σου.'
      : 'Allow your friends to see your grades.';
  String get gradesHidden => lang == 'el' ? 'Βαθμοί κρυφοί' : 'Grades hidden';
  String get searchUsers => lang == 'el' ? 'Αναζήτηση Χρηστών' : 'Search Users';
  String get noUsersFound =>
      lang == 'el' ? 'Δεν βρέθηκαν χρήστες.' : 'No users found.';
  String get sendRequest => lang == 'el' ? 'Αποστολή' : 'Send';
  String get accept => lang == 'el' ? 'Αποδοχή' : 'Accept';
  String get decline => lang == 'el' ? 'Απόρριψη' : 'Decline';
  String get newRequest =>
      lang == 'el' ? 'Νέο Αίτημα Φιλίας' : 'New Friend Request';
  String get userBlocked =>
      lang == 'el' ? 'Ο χρήστης αποκλείστηκε.' : 'User blocked.';
  String get userUnblocked =>
      lang == 'el' ? 'Ο αποκλεισμός αφαιρέθηκε.' : 'User unblocked.';
  String get reportedSuccessfully => lang == 'el'
      ? 'Η αναφορά υποβλήθηκε.'
      : 'Report submitted.';
  String get reportFailed =>
      lang == 'el' ? 'Αποτυχία αναφοράς' : 'Report failed';
  String get pollVoteFailed => lang == 'el'
      ? 'Δεν ήταν δυνατή η ψήφος.'
      : 'Could not register vote.';
  String get blockedUsers =>
      lang == 'el' ? 'Αποκλεισμένοι χρήστες' : 'Blocked users';
  String get unblock => lang == 'el' ? 'Αφαίρεση αποκλεισμού' : 'Unblock';
  String get noBlockedUsers => lang == 'el'
      ? 'Δεν έχεις αποκλείσει κανέναν.'
      : 'You have not blocked anyone.';

  // --- Profile Management ---
  String get editProfile =>
      lang == 'el' ? 'Επεξεργασία Προφίλ' : 'Edit Profile';
  String get profilePictureUpdated =>
      lang == 'el' ? 'Η φωτογραφία ενημερώθηκε!' : 'Profile picture updated!';
  String get profileUpdated =>
      lang == 'el' ? 'Το προφίλ ενημερώθηκε!' : 'Profile updated!';
  String get changePassword =>
      lang == 'el' ? 'Αλλαγή Κωδικού' : 'Change Password';
  String get currentPassword =>
      lang == 'el' ? 'Τρέχων Κωδικός' : 'Current Password';
  String get newPassword => lang == 'el' ? 'Νέος Κωδικός' : 'New Password';
  String get confirmPassword =>
      lang == 'el' ? 'Επιβεβαίωση Κωδικού' : 'Confirm Password';
  String get passwordsDoNotMatch =>
      lang == 'el' ? 'Οι κωδικοί δεν ταιριάζουν.' : 'Passwords do not match.';
  String get passwordTooShort => lang == 'el'
      ? 'Ο κωδικός πρέπει να είναι τουλάχιστον 6 χαρακτήρες.'
      : 'Password must be at least 6 characters.';
  String get passwordChanged => lang == 'el'
      ? 'Ο κωδικός άλλαξε επιτυχώς!'
      : 'Password changed successfully!';
  String get dangerZone => lang == 'el' ? 'Ζώνη Κινδύνου' : 'Danger Zone';
  String get deleteAccount =>
      lang == 'el' ? 'Διαγραφή Λογαριασμού' : 'Delete Account';
  String get deleteAccountWarning => lang == 'el'
      ? 'Αυτή η ενέργεια είναι μόνιμη. Θα διαγραφούν όλα τα δεδομένα σας.'
      : 'This action is permanent. All your data will be deleted.';
  String get signInWithGoogle =>
      lang == 'el' ? 'Σύνδεση με Google' : 'Sign in with Google';

  // --- AI Study Assistant ---
  String get aiStudyAssistantTitle =>
      lang == 'el' ? 'AI Βοηθός Μελέτης' : 'AI Study Assistant';
  String get aiStudyAssistantSidebar =>
      lang == 'el' ? 'AI Βοηθός' : 'AI Assistant';
  String get aiNewChat => lang == 'el' ? 'Νέα Συζήτηση' : 'New Chat';
  String get aiChatInProgress => lang == 'el' ? 'Σε εξέλιξη' : 'In progress';
  String get aiWelcomePitch => lang == 'el'
      ? 'Γεια σου! Είμαι ο ScholiLink AI.\nΠώς μπορώ να σε βοηθήσω σήμερα;'
      : 'Hello! I am ScholiLink AI.\nHow can I help you today?';
  String get aiAskAnythingHint =>
      lang == 'el' ? 'Ρώτα με οτιδήποτε...' : 'Ask me anything...';
  String get aiHistorySection => lang == 'el' ? 'Ιστορικό' : 'History';
  String get aiChatHistoryDrawerTitle =>
      lang == 'el' ? 'Ιστορικό Συζητήσεων' : 'Chat history';
  String get aiNoChatsYet =>
      lang == 'el' ? 'Δεν υπάρχουν συζητήσεις ακόμα.' : 'No conversations yet.';
  String get aiCopied => lang == 'el' ? 'Αντιγράφηκε' : 'Copied';
  String get aiCopy => lang == 'el' ? 'Αντιγραφή' : 'Copy';

  // --- Smart Notes ---
  String get smartNotesTitle =>
      lang == 'el' ? 'Έξυπνες Σημειώσεις' : 'Smart Notes';
  String get smartNotesWelcome => lang == 'el'
      ? 'Δημιούργησε έξυπνες σημειώσεις\nαπό το κείμενο ή τις εικόνες σου!'
      : 'Create smart notes from your text or images!';
  String get smartNotesNoteSettingsLabel =>
      lang == 'el' ? 'Ρυθμίσεις σημείωσης' : 'Note settings';
  String get smartNotesPasteOrAskHint => lang == 'el'
      ? 'Επικόλλησε κείμενο ή κάνε μια ερώτηση...'
      : 'Paste text or ask a question...';
  String get smartNotesNewNotes =>
      lang == 'el' ? 'Νέες Σημειώσεις' : 'New Notes';
  String get smartNotesSidebarShort => lang == 'el' ? 'Σημειώσεις' : 'Notes';
  String get smartNotesHistoryDrawerTitle =>
      lang == 'el' ? 'Ιστορικό Σημειώσεων' : 'Notes history';
  String get smartNotesNoNotesYet =>
      lang == 'el' ? 'Δεν υπάρχουν σημειώσεις ακόμα.' : 'No notes yet.';
  String get smartNotesPromptFromImagesOnly => lang == 'el'
      ? 'Δημιούργησε σημειώσεις από τις εικόνες που έστειλα.'
      : 'Create notes from the images I sent.';
  String get smartNotesLengthSection =>
      lang == 'el' ? 'Μέγεθος σημείωσης' : 'Note length';
  String get smartNotesDepthSection =>
      lang == 'el' ? 'Βάθος ανάλυσης' : 'Analysis depth';
  String get smartNotesLenShort => lang == 'el' ? 'Σύντομη' : 'Short';
  String get smartNotesLenMedium => lang == 'el' ? 'Μεσαία' : 'Medium';
  String get smartNotesLenLong => lang == 'el' ? 'Μεγάλη' : 'Long';
  String get smartNotesDepthBasic => lang == 'el' ? 'Βασική' : 'Basic';
  String get smartNotesDepthStandard => lang == 'el' ? 'Τυπική' : 'Standard';
  String get smartNotesDepthInDepth => lang == 'el' ? 'Σε βάθος' : 'In depth';

  // --- Classroom Multi ---
  String get myClassrooms => lang == 'el' ? 'Οι Τάξεις μου' : 'My Classrooms';
  String get admin => lang == 'el' ? 'Διαχειριστής' : 'Admin';
  String get member => lang == 'el' ? 'Μέλος' : 'Member';
  String get you => lang == 'el' ? 'Εσύ' : 'You';
  String get classroomSettings =>
      lang == 'el' ? 'Ρυθμίσεις Τάξης' : 'Classroom Settings';
  String get classroomNotFound =>
      lang == 'el' ? 'Η τάξη δεν βρέθηκε.' : 'Classroom not found.';
  String get editClassroom =>
      lang == 'el' ? 'Επεξεργασία Τάξης' : 'Edit Classroom';
  String get description => lang == 'el' ? 'Περιγραφή' : 'Description';
  String get save => lang == 'el' ? 'Αποθήκευση' : 'Save';
  String get settings => lang == 'el' ? 'Ρυθμίσεις' : 'Settings';
  String get themeAppearance =>
      lang == 'el' ? 'Εμφάνιση εφαρμογής' : 'App appearance';
  String get themeAppearanceDesc => lang == 'el'
      ? 'Φωτεινό, σκοτεινό ή αυτόματα όπως η συσκευή σας.'
      : 'Light, dark, or match your device.';
  String get themeLight => lang == 'el' ? 'Πάντα φωτεινό' : 'Always light';
  String get themeDark => lang == 'el' ? 'Πάντα σκοτεινό' : 'Always dark';
  String get themeSystem =>
      lang == 'el' ? 'Προεπιλογή συστήματος' : 'System default';
  String get promoteToAdmin =>
      lang == 'el' ? 'Αναβάθμιση σε Διαχειριστή' : 'Promote to Admin';
  String get demoteAdmin =>
      lang == 'el' ? 'Υποβάθμιση Διαχειριστή' : 'Demote Admin';
  String get removeMember => lang == 'el' ? 'Αφαίρεση Μέλους' : 'Remove Member';
  String get leaveClassroom =>
      lang == 'el' ? 'Αποχώρηση από Τάξη' : 'Leave Classroom';
  String get leaveConfirm => lang == 'el'
      ? 'Είστε σίγουροι ότι θέλετε να αποχωρήσετε;'
      : 'Are you sure you want to leave?';
  String get leave => lang == 'el' ? 'Αποχώρηση' : 'Leave';
  String get deleteClassroom =>
      lang == 'el' ? 'Διαγραφή Τάξης' : 'Delete Classroom';
  String get deleteClassroomConfirm => lang == 'el'
      ? 'Αυτό θα διαγράψει μόνιμα την τάξη και όλα τα δεδομένα.'
      : 'This will permanently delete the classroom and all its data.';
  String get delete => lang == 'el' ? 'Διαγραφή' : 'Delete';

  // --- Chat & Messaging ---
  String get noMessagesYet =>
      lang == 'el' ? 'Δεν υπάρχουν μηνύματα ακόμα.' : 'No messages yet.';
  String get typeMessage =>
      lang == 'el' ? 'Πληκτρολογήστε μήνυμα...' : 'Type a message...';
  String get academicMode => lang == 'el' ? 'Ακαδημαϊκό' : 'Academic';
  String get switchToSocial =>
      lang == 'el' ? 'Κοινωνική λειτουργία' : 'Switch to Social';
  String get switchToAcademic =>
      lang == 'el' ? 'Ακαδημαϊκή λειτουργία' : 'Switch to Academic';
  String get subjectHint => lang == 'el' ? 'Μάθημα...' : 'Subject...';
  String get attachPhoto =>
      lang == 'el' ? 'Επισύναψη φωτογραφίας' : 'Attach photo';
  String get voiceMessage => lang == 'el' ? 'Ηχητικό μήνυμα' : 'Voice message';
  String get messageDeleted =>
      lang == 'el' ? 'Αυτό το μήνυμα διαγράφηκε.' : 'This message was deleted.';
  String get editingMessage =>
      lang == 'el' ? 'Επεξεργασία μηνύματος' : 'Editing message';
  String get edited => lang == 'el' ? 'διορθώθηκε' : 'edited';
  String get edit => lang == 'el' ? 'Επεξεργασία' : 'Edit';
  String get profanityDetected =>
      lang == 'el' ? 'Μη αποδεκτό περιεχόμενο.' : 'Profanity detected.';

  // --- Polls ---
  String get createPoll =>
      lang == 'el' ? 'Δημιουργία Ψηφοφορίας' : 'Create Poll';
  String get poll => lang == 'el' ? 'Ψηφοφορία' : 'Poll';
  String get pollQuestion => lang == 'el' ? 'Ερώτηση' : 'Question';
  String get pollOptions => lang == 'el' ? 'Επιλογές' : 'Options';
  String get option => lang == 'el' ? 'Επιλογή' : 'Option';
  String get addOption => lang == 'el' ? 'Προσθήκη Επιλογής' : 'Add Option';
  String get anonymousPoll =>
      lang == 'el' ? 'Ανώνυμη ψηφοφορία' : 'Anonymous poll';
  String get anonymousPollDesc => lang == 'el'
      ? 'Οι ψηφοφόροι δεν θα φαίνονται.'
      : 'Voters will not be visible.';
  String get allowMultipleVotes =>
      lang == 'el' ? 'Πολλαπλές ψήφοι' : 'Allow multiple votes';
  String get votes => lang == 'el' ? 'ψήφοι' : 'votes';
  String get anonymous => lang == 'el' ? 'Ανώνυμη' : 'Anonymous';
  String get pollNotFound =>
      lang == 'el' ? 'Η ψηφοφορία δεν βρέθηκε.' : 'Poll not found.';

  // --- Grades ---
  String get myGrades => lang == 'el' ? 'Οι Βαθμοί μου' : 'My Grades';
  String get addGrade => lang == 'el' ? 'Προσθήκη Βαθμού' : 'Add Grade';
  String get gradeValue => lang == 'el' ? 'Βαθμός (0-20)' : 'Grade (0-20)';
  String get term => lang == 'el' ? 'Τετράμηνο' : 'Term';
  String get schoolYear => lang == 'el' ? 'Σχολικό Έτος' : 'School Year';
  String get gradeProgress =>
      lang == 'el' ? 'Πρόοδος Βαθμών' : 'Grade Progress';
  String get noGradesYet =>
      lang == 'el' ? 'Δεν υπάρχουν βαθμοί ακόμα.' : 'No grades yet.';
  String get gradeAddedSuccess =>
      lang == 'el' ? 'Ο βαθμός προστέθηκε!' : 'Grade added successfully!';
  String get homeworkAdded => lang == 'el'
      ? 'Η εργασία προστέθηκε αυτόματα!'
      : 'Homework added automatically!';
  String get homeworkPosted => lang == 'el'
      ? 'Η εργασία αναρτήθηκε στην τάξη!'
      : 'Homework posted to class!';
  String get subjectFocusAlert =>
      lang == 'el' ? 'Εστίαση Μαθήματος' : 'Subject Focus Alert';
  String get conflictWarning => lang == 'el'
      ? 'Προσοχή: Έχετε Διαγώνισμα (Σχολείο) και Εργασία (Φροντιστήριο) την ίδια μέρα!'
      : 'Attention: You have an Exam (School) and Homework (Tutor) on the same day!';
  String get addHomework => lang == 'el' ? 'Προσθήκη Εργασίας' : 'Add Homework';
  String get addGrades => lang == 'el' ? 'Προσθήκη Βαθμών' : 'Add Grades';
  String get selectSubject =>
      lang == 'el' ? 'Επιλογή μαθήματος' : 'Select subject';
  String get selectTerm => lang == 'el' ? 'Επιλέξτε Τετράμηνο' : 'Select Term';
  String get averageGrade => lang == 'el' ? 'Μέσος Όρος' : 'Average';

  // --- Exam Results ---
  String get examResults =>
      lang == 'el' ? 'Αποτελέσματα Εξετάσεων' : 'Exam Results';
  String get addExamResult =>
      lang == 'el' ? 'Προσθήκη Αποτελέσματος' : 'Add Result';
  String get examName => lang == 'el' ? 'Όνομα Εξέτασης' : 'Exam Name';
  String get score => lang == 'el' ? 'Βαθμολογία (0-20)' : 'Score (0-20)';
  String get examResultsProgress =>
      lang == 'el' ? 'Πρόοδος Εξετάσεων' : 'Exam Results Progress';
  String get noExamResultsYet => lang == 'el'
      ? 'Δεν υπάρχουν αποτελέσματα ακόμα.'
      : 'No exam results yet.';
  String get resultAddedSuccess =>
      lang == 'el' ? 'Το αποτέλεσμα προστέθηκε!' : 'Result added successfully!';

  // --- Settings ---
  String get autoAddHomework =>
      lang == 'el' ? 'Αυτόματη Προσθήκη Εργασιών' : 'Auto-Add Homework';
  String get autoAddHomeworkDesc => lang == 'el'
      ? 'Όταν μια εργασία επαληθευτεί στα μαθήματά σου, προστίθεται αυτόματα.'
      : 'When a homework is verified in your subjects, it gets added automatically.';
  String get manageSubjects =>
      lang == 'el' ? 'Διαχείριση Μαθημάτων' : 'Manage Subjects';
  String get manageSubjectsDesc => lang == 'el'
      ? 'Προσθήκη ή αφαίρεση μαθημάτων.'
      : 'Add or remove subjects.';
  String get addCustomSubject =>
      lang == 'el' ? 'Προσθήκη Μαθήματος' : 'Add Custom Subject';
  String get customSubjectHint =>
      lang == 'el' ? 'Όνομα μαθήματος' : 'Subject name';

  // --- Calendar Widget ---
  String get schoolCalendar =>
      lang == 'el' ? 'Σχολικό Ημερολόγιο' : 'School Calendar';
  String get noUpcomingEvents =>
      lang == 'el' ? 'Δεν υπάρχουν προσεχή γεγονότα.' : 'No upcoming events.';

  // --- Homework Types & Enhanced ---
  String get homeworkType => lang == 'el' ? 'Τύπος Εργασίας' : 'Homework Type';
  String get dailyHomework => lang == 'el' ? 'Καθημερινή' : 'Daily';
  String get projectHomework => lang == 'el' ? 'Εργασία / Project' : 'Project';
  String get otherHomework => lang == 'el' ? 'Άλλο' : 'Other';
  String get dueDate => lang == 'el' ? 'Ημερομηνία Παράδοσης' : 'Due Date';
  String get selectDueDate =>
      lang == 'el' ? 'Επιλέξτε ημερομηνία' : 'Select due date';
  String get totalHomework =>
      lang == 'el' ? 'Σύνολο Εργασιών' : 'Total Homework';
  String get markComplete => lang == 'el' ? 'Ολοκληρώθηκε' : 'Mark Complete';
  String get addVoiceNote => lang == 'el' ? 'Ηχογράφηση' : 'Voice Note';
  String get addPhotos => lang == 'el' ? 'Φωτογραφίες' : 'Photos';
  String get tomorrowHomework =>
      lang == 'el' ? 'Εργασίες για Αύριο' : 'Tomorrow\'s Homework';
  String get noHomeworkTomorrow => lang == 'el'
      ? 'Δεν υπάρχουν εργασίες για αύριο! 🎉'
      : 'No homework for tomorrow! 🎉';

  // --- Homework History ---
  String get homeworkHistory =>
      lang == 'el' ? 'Ιστορικό Εργασιών' : 'Homework History';
  String get completedHomework =>
      lang == 'el' ? 'Ολοκληρωμένες εργασίες' : 'Completed homework';

  // --- Tutoring ---
  String get manageTutoring =>
      lang == 'el' ? 'Διαχείριση Ιδιαίτερων' : 'Manage Tutoring';
  String get hasTutoring => lang == 'el' ? 'Κάνω ιδιαίτερα' : 'I have tutoring';
  String get tutoringSubjects =>
      lang == 'el' ? 'Μαθήματα Ιδιαίτερων' : 'Tutoring Subjects';
  String get tutoringDesc => lang == 'el'
      ? 'Επιλέξτε τα μαθήματα στα οποία κάνετε ιδιαίτερα.'
      : 'Select subjects you have tutoring for.';

  // --- Term System ---
  String get firstTerm => lang == 'el' ? '1ο Τετράμηνο' : '1st Term';
  String get secondTerm => lang == 'el' ? '2ο Τετράμηνο' : '2nd Term';
  String get finalExams => lang == 'el' ? 'Τελικές Εξετάσεις' : 'Final Exams';

  // --- Parental Consent ---
  String get parentalConsentRequired => lang == 'el'
      ? 'Απαιτείται Γονική Συγκατάθεση'
      : 'Parental Consent Required';
  String get parentalConsentDesc => lang == 'el'
      ? 'Λόγω ηλικίας (< 15 ετών), απαιτείται η συγκατάθεση κηδεμόνα για τη χρήση των λειτουργιών AI.'
      : 'Due to your age (< 15), parental consent is required to use AI features.';
  String get parentalConsentPending => lang == 'el'
      ? 'Ένας κωδικός επιβεβαίωσης εστάλη στο email του κηδεμόνα.'
      : 'A verification code has been sent to your parent\'s email.';
  String get parentalConsentPrompt => lang == 'el'
      ? 'Παρακαλώ εισάγετε το email του κηδεμόνα σας για να του σταλεί ο κωδικός πρόσβασης.'
      : 'Please enter your parent\'s email to send a verification code.';
  String get parentEmail => lang == 'el' ? 'Email Κηδεμόνα' : 'Parent\'s Email';
  String get sendConsentRequest =>
      lang == 'el' ? 'Αποστολή Αιτήματος' : 'Send Request';
  String get invalidEmail => lang == 'el' ? 'Μη έγκυρο email' : 'Invalid email';
  String get consentRequestSent =>
      lang == 'el' ? 'Εστάλη αίτημα συγκατάθεσης.' : 'Consent request sent.';
  String get enterPin =>
      lang == 'el' ? 'Εισάγετε τον κωδικό' : 'Enter the code';
  String get verificationCode =>
      lang == 'el' ? 'Κωδικός Επιβεβαίωσης' : 'Verification Code';
  String get verifyConsent => lang == 'el' ? 'Επιβεβαίωση' : 'Verify';
  String get consentVerifiedSuccess =>
      lang == 'el' ? 'Επιτυχής επιβεβαίωση!' : 'Consent verified successfully!';
  String get invalidPin => lang == 'el'
      ? 'Λάθος κωδικός (Δοκιμάστε: 1234)'
      : 'Invalid code (Try: 1234)';
  String get sentTo => lang == 'el' ? 'Εστάλη στο' : 'Sent to';
  String get schoolProgram =>
      lang == 'el' ? 'Σχολικό Πρόγραμμα' : 'School Program';
  String get tutoringProgram =>
      lang == 'el' ? 'Πρόγραμμα Ιδιαίτερων' : 'Tutoring Program';
}

// Extension to easily access S from context if we had a provider,
// but for now we'll pass the language string directly.
extension LocalizationExtension on BuildContext {
  S l10n(String lang) => S(lang);
}
