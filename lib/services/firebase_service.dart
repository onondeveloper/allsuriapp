import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_storage/firebase_storage.dart';
import '../models/user.dart' as app_user;
import '../models/order.dart';
import '../models/estimate.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Authentication methods
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Failed to sign in: $e');
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Firestore methods
  Future<void> createUser(app_user.User user) async {
    try {
      await _firestore.collection('users').doc(user.id).set(user.toJson());
    } catch (e) {
      throw Exception('Failed to create user in Firestore: $e');
    }
  }

  Future<app_user.User?> getUser(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return app_user.User.fromJson(doc.data()! as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  Future<List<app_user.User>> getUsers() async {
    try {
      final querySnapshot = await _firestore.collection('users').get();
      return querySnapshot.docs
          .map((doc) => app_user.User.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }

  Future<void> createOrder(Order order) async {
    try {
      await _firestore.collection('orders').doc(order.id).set(order.toJson());
    } catch (e) {
      throw Exception('Failed to create order: $e');
    }
  }

  Future<List<Order>> getOrders() async {
    try {
      final querySnapshot = await _firestore.collection('orders').get();
      return querySnapshot.docs
          .map((doc) => Order.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get orders: $e');
    }
  }

  Future<void> createEstimate(Estimate estimate) async {
    try {
      await _firestore.collection('estimates').doc(estimate.id).set(estimate.toJson());
    } catch (e) {
      throw Exception('Failed to create estimate: $e');
    }
  }

  Future<List<Estimate>> getEstimates() async {
    try {
      final querySnapshot = await _firestore.collection('estimates').get();
      return querySnapshot.docs
          .map((doc) => Estimate.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to get estimates: $e');
    }
  }

  // Storage methods
  Future<String> uploadFile(String filePath, String fileName) async {
    try {
      final ref = _storage.ref().child(fileName);
      final uploadTask = await ref.putFile(File(filePath));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<void> deleteFile(String fileName) async {
    try {
      final ref = _storage.ref().child(fileName);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}
