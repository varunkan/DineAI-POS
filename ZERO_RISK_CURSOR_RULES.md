# 🚨 ABSOLUTE ZERO RISK CURSOR RULES - PERMANENT DOCUMENTATION

## **THIS FILE IS PERMANENT AND MUST NEVER BE DELETED**

**File Location**: `.cursorrules` (root directory)
**Backup Location**: `ZERO_RISK_CURSOR_RULES.md` (this file)

---

## 🚨 **CRITICAL: ABSOLUTE ZERO RISK MANDATE**

**THIS RULE CAN NEVER BE BREACHED, EVEN IF THE LAPTOP SHUTS DOWN AND RESTARTS**

### **PRIMARY DIRECTIVE: ZERO RISK TO EXISTING FUNCTIONALITY**

When writing code or making changes to the application, the AI assistant MUST:

1. **NEVER modify existing working code without comprehensive safety measures**
2. **ALWAYS implement rollback mechanisms before any data changes**
3. **ALWAYS create backups before modifying critical data structures**
4. **NEVER break existing functionality, even if it means not implementing new features**
5. **ALWAYS use feature flags for new functionality**
6. **ALWAYS implement graceful degradation on failures**

---

## 📋 **MANDATORY SAFETY PROTOCOLS**

### **Before ANY Code Changes:**
- [ ] Search existing codebase for similar functionality
- [ ] Identify ALL dependencies and potential impact points
- [ ] Create comprehensive backup/rollback strategy
- [ ] Implement feature flags for new code
- [ ] Test rollback mechanisms

### **During Code Changes:**
- [ ] Use try-catch blocks around ALL new functionality
- [ ] Implement automatic rollback on ANY failure
- [ ] Never throw errors that could break existing flow
- [ ] Always provide fallback to existing functionality
- [ ] Log ALL operations for debugging

### **After Code Changes:**
- [ ] Verify existing functionality still works
- [ ] Test rollback mechanisms
- [ ] Document all safety measures implemented
- [ ] Provide emergency disable instructions

---

## 💻 **ZERO RISK IMPLEMENTATION REQUIREMENTS**

### **Data Operations (REQUIRED PATTERN):**
```dart
// REQUIRED PATTERN for ANY data modification:
try {
  // 1. Create backup
  final backup = await createBackup();
  
  // 2. Attempt operation
  await performOperation();
  
  // 3. Verify success
  await verifyOperation();
  
} catch (e) {
  // 4. Automatic rollback on ANY failure
  await rollbackFromBackup(backup);
  // 5. Never throw - use existing functionality
  logError(e);
}
```

### **Feature Flags (REQUIRED for ALL new functionality):**
```dart
// REQUIRED for ALL new functionality:
static const bool _enableNewFeature = true; // Can be disabled instantly

// Check flag before execution:
if (!_enableNewFeature) {
  // Use existing functionality only
  return existingFunction();
}
```

### **Error Handling (REQUIRED pattern):**
```dart
// REQUIRED pattern - NEVER break existing flow:
try {
  newFunctionality();
} catch (e) {
  // Log error but continue with existing functionality
  logError(e);
  // NEVER rethrow - this breaks the zero risk mandate
}
```

---

## 🚨 **EMERGENCY PROCEDURES**

### **If ANY Risk is Detected:**
1. **IMMEDIATELY disable new functionality** via feature flags
2. **Rollback to last known good state**
3. **Restore from backups**
4. **Document the issue and safety measures needed**

### **Emergency Disable Commands:**
```dart
// Set ALL feature flags to false:
static const bool _enableNewFeature = false;
static const bool _enableEnhancedSync = false;
static const bool _enableSafeWrappers = false;
```

---

## ✅ **CODE REVIEW REQUIREMENTS**

### **Before Approving ANY Changes:**
- [ ] All existing functionality preserved
- [ ] Rollback mechanisms tested
- [ ] Feature flags implemented
- [ ] Error handling comprehensive
- [ ] No breaking changes introduced
- [ ] Backup strategies documented

### **Red Flags (IMMEDIATE REJECTION):**
- ❌ Direct modification of existing working code without safety measures
- ❌ No rollback mechanisms
- ❌ No feature flags
- ❌ Breaking changes to existing APIs
- ❌ No error handling
- ❌ No backup strategies

---

## 🔒 **PERMANENT ENFORCEMENT**

This rule is **PERMANENT** and **IMMUTABLE**. It applies to:
- All AI assistants working on this codebase
- All code changes, regardless of urgency
- All new features and bug fixes
- All data modifications
- All system integrations

---

## 🔍 **COMPLIANCE VERIFICATION**

Before ANY code is committed or deployed:
1. **Verify zero risk compliance**
2. **Test all safety mechanisms**
3. **Confirm existing functionality intact**
4. **Document all safety measures**
5. **Provide rollback instructions**

---

## 🚨 **REMEMBER: ZERO RISK IS NOT NEGOTIABLE**

**If you cannot implement a feature with ZERO RISK to existing functionality, DO NOT IMPLEMENT IT.**

**Existing functionality is SACRED and must NEVER be compromised.**

**When in doubt, choose safety over features.**

**This rule is PERMANENT and applies to ALL future AI interactions with this codebase.**

---

## 📍 **FILE LOCATIONS**

- **Primary Rules**: `.cursorrules` (root directory)
- **Backup Documentation**: `ZERO_RISK_CURSOR_RULES.md` (this file)
- **Implementation Example**: `lib/services/multi_tenant_auth_service.dart` (safe wrapper methods)

---

## 🆘 **EMERGENCY CONTACT**

If this rule is ever compromised or if you need to restore the zero risk mandate:
1. **Check `.cursorrules` file exists**
2. **Verify `ZERO_RISK_CURSOR_RULES.md` exists**
3. **Recreate missing files from this documentation**
4. **Ensure ALL AI assistants follow these rules**

---

**Last Updated**: Current Date
**Status**: PERMANENT AND ACTIVE
**Enforcement**: MANDATORY FOR ALL AI ASSISTANTS 