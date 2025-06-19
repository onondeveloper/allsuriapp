import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../models/role.dart';
import '../services/firebase_service.dart';

class UserProvider with ChangeNotifier {
  final FirebaseService _firebaseService;
  List<User> _businessUsers = [];
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserProvider(this._firebaseService);

  List<User> get businessUsers => _businessUsers;
  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadBusinessUsers() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final users = await _firebaseService.getUsers();
      _businessUsers = users.where((user) => user.role == UserRole.pro).toList();
    } catch (e) {
      _error = e.toString();
      print('Error loading business users: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userCredential = await _firebaseService.signInWithEmailAndPassword(email, password);
      _currentUser = await _firebaseService.getUser(userCredential.user!.uid);
    } catch (e) {
      _error = e.toString();
      print('Error signing in: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signUp(String email, String password, String name, UserRole role) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final userCredential = await _firebaseService.createUserWithEmailAndPassword(email, password);
      final user = User(
        id: userCredential.user!.uid,
        email: email,
        name: name,
        role: role,
        createdAt: DateTime.now(),
      );
      await _firebaseService.createUser(user);
      _currentUser = user;
    } catch (e) {
      _error = e.toString();
      print('Error signing up: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.signOut();
      _currentUser = null;
    } catch (e) {
      _error = e.toString();
      print('Error signing out: $e');
    }

    _isLoading = false;
    notifyListeners();
  }
}