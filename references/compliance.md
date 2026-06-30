# Regulatory Compliance Reference

## Table of Contents
1. [GDPR](#gdpr)
2. [HIPAA](#hipaa)
3. [SOC 2](#soc-2)
4. [PCI-DSS](#pci-dss)
5. [Data Retention](#data-retention)
6. [Right to Erasure](#right-to-erasure)
7. [Data Portability](#data-portability)
8. [Consent Management](#consent-management)
9. [Privacy by Design](#privacy-by-design)
10. [Cross-Border Data Transfer](#cross-border-data-transfer)
11. [Audit Logging](#audit-logging)
12. [Compliance Checklists](#compliance-checklists)

---

## GDPR

### Data Subject Rights

The General Data Protection Regulation (GDPR) grants individuals (data subjects) eight fundamental rights:

| Right | Description | Implementation |
|-------|-------------|----------------|
| **Access** | Know what data is stored and why | `/api/me/export` endpoint, data inventory |
| **Rectification** | Correct inaccurate data | `PATCH /api/me` endpoint with validation |
| **Erasure** | Delete personal data ("right to be forgotten") | Cascade deletion, soft delete, audit trail |
| **Portability** | Receive data in machine-readable format | JSON/CSV export, standardized schema |
| **Restriction** | Limit processing under certain conditions | Processing flags, consent states |
| **Objection** | Object to processing (including profiling) | Preference center, opt-out mechanisms |
| **Automated Decision-Making** | Challenge purely automated decisions | Human review process, explanation logic |
| **Consent Withdrawal** | Withdraw consent anytime | Immediate effect, audit trail |

### Lawful Basis for Processing

```typescript
// lawful-basis.ts
enum LawfulBasis {
  CONSENT = 'consent',           // Explicit opt-in
  CONTRACT = 'contract',         // Necessary for service delivery
  LEGAL_OBLIGATION = 'legal',    // Required by law (e.g., tax records)
  VITAL_INTERESTS = 'vital',     // Life-or-death situations
  PUBLIC_TASK = 'public',        // Public interest/official authority
  LEGITIMATE_INTERESTS = 'legitimate', // Balanced against user rights
}

interface DataProcessingRecord {
  purpose: string;
  lawfulBasis: LawfulBasis;
  dataCategories: string[];
  retentionPeriodDays: number;
  thirdPartyRecipients: string[];
  safeguards: string[];
  dpoConsulted: boolean;
  lastReviewedAt: Date;
}
```

### Consent Requirements

```typescript
// consent-management.ts
interface ConsentRecord {
  id: string;
  userId: string;
  purpose: string;           // e.g., 'marketing', 'analytics'
  granted: boolean;
  granularity: string[];     // Specific categories consented to
  channel: string;            // Where consent was collected
  ipAddress: string;          // IP at time of consent
  userAgent: string;
  timestamp: Date;
  version: string;            // Consent form version
  language: string;
  withdrawnAt: Date | null;
  withdrawalMethod: string | null;
}

class ConsentManager {
  async recordConsent(userId: string, purpose: string, granted: boolean, metadata: object): Promise<void> {
    const record: ConsentRecord = {
      id: generateUUID(),
      userId,
      purpose,
      granted,
      granularity: metadata['categories'] || [purpose],
      channel: metadata['channel'] || 'web',
      ipAddress: metadata['ip'] || 'unknown',
      userAgent: metadata['ua'] || 'unknown',
      timestamp: new Date(),
      version: metadata['version'] || '1.0',
      language: metadata['language'] || 'en',
      withdrawnAt: null,
      withdrawalMethod: null,
    };

    await this.db.consent.create({ data: record });
    await this.auditLog('CONSENT_RECORDED', record);
  }

  async withdrawConsent(userId: string, purpose: string): Promise<void> {
    await this.db.consent.updateMany({
      where: { userId, purpose, withdrawnAt: null },
      data: {
        granted: false,
        withdrawnAt: new Date(),
        withdrawalMethod: 'user_portal',
      },
    });

    // Trigger data deletion for consent-based processing
    await this.triggerErasureWorkflow(userId, purpose);
  }
}
```

### DPO Appointment

Organizations must appoint a Data Protection Officer if they:
- Are a public authority
- Engage in large-scale systematic monitoring
- Process large-scale sensitive data

```typescript
// dpo-contact.ts
const dpoContact = {
  name: 'Jane Smith',
  email: 'dpo@company.com',
  phone: '+1-555-0100',
  address: '123 Privacy Lane, Data City, DC 12345',
  responsibilities: [
    'Monitor GDPR compliance',
    'Provide advice on DPIAs',
    'Cooperate with supervisory authority',
    'Be first point of contact for data subjects',
  ],
};
```

### Breach Notification

```typescript
// breach-notification.ts
interface DataBreach {
  discoveredAt: Date;
  affectedSubjects: number;
  affectedCategories: string[]; // 'email', 'password', 'financial'
  likelihoodOfResultingRisk: 'high' | 'low';
  severityOfPotentialImpact: 'high' | 'low';
  measuresTaken: string[];
  measuresProposed: string[];
}

async function assessBreachNotificationRequirement(breach: DataBreach): Promise<{ notifyAuthority: boolean; notifySubjects: boolean }> {
  const notifyAuthority = breach.affectedSubjects > 0; // Always if personal data involved
  const notifySubjects = breach.likelihoodOfResultingRisk === 'high' || breach.severityOfPotentialImpact === 'high';

  return { notifyAuthority, notifySubjects };
}

// Timeline: Notify supervisory authority within 72 hours
// Notify data subjects without undue delay if high risk
```

---

## HIPAA

### Protected Health Information (PHI)

HIPAA applies to Covered Entities (healthcare providers, insurers) and Business Associates (vendors handling PHI).

**18 PHI Identifiers:**
- Names, addresses, dates (except year), phone/fax/email
- SSN, medical record numbers, health plan IDs
- Account numbers, certificate/license numbers
- Vehicle IDs, device IDs, biometric identifiers
- Full-face photos, any other unique identifiers

### Business Associate Agreement (BAA)

```typescript
// baa-requirements.ts
interface BusinessAssociateAgreement {
  coveredEntity: string;
  businessAssociate: string;
  permittedUses: string[];
  safeguards: string[];
  subcontractorProvisions: boolean;
  breachNotificationRequirements: {
    timeframe: '24 hours' | '72 hours' | 'reasonable';
    method: string;
  };
  returnOrDestructionOfPHI: 'return' | 'destroy' | 'either';
  auditRights: boolean;
  term: string;
  terminationConditions: string[];
}

// Required safeguards in BAA
const requiredSafeguards = [
  'Administrative safeguards (policies, procedures)',
  'Physical safeguards (facility access, workstation security)',
  'Technical safeguards (access control, audit controls, integrity, transmission security)',
];
```

### Access Controls

```typescript
// hipaa-access-control.ts
import { Role } from '@prisma/client';

interface HIPAAAccessControl {
  userId: string;
  role: Role;
  accessLevel: 'minimum_necessary' | 'full' | 'none';
  permittedDataClasses: string[];
  permittedPatients: string[] | 'all'; // Restricted list for minimum necessary
  accessLogEnabled: boolean;
  sessionTimeoutMinutes: number;
  mfaRequired: boolean;
}

class HIPAAAccessManager {
  async checkAccess(userId: string, patientId: string, action: 'read' | 'write' | 'delete'): Promise<boolean> {
    const access = await this.getAccessControl(userId);

    // Minimum necessary rule: only access needed for role
    if (access.accessLevel === 'minimum_necessary') {
      if (access.permittedPatients !== 'all' && !access.permittedPatients.includes(patientId)) {
        await this.logDeniedAccess(userId, patientId, action, 'PATIENT_NOT_IN_SCOPE');
        return false;
      }
    }

    await this.logAccess(userId, patientId, action);
    return true;
  }

  async logAccess(userId: string, patientId: string, action: string): Promise<void> {
    await this.db.accessLog.create({
      data: {
        userId,
        patientId,
        action,
        timestamp: new Date(),
        ipAddress: this.context.ipAddress,
        userAgent: this.context.userAgent,
        success: true,
      },
    });
  }
}
```

### Encryption Requirements

```typescript
// hipaa-encryption.ts
interface EncryptionConfig {
  atRest: {
    algorithm: 'AES-256-GCM';
    keyManagement: 'AWS KMS' | 'HashiCorp Vault' | 'HSM';
    keyRotationDays: 90;
  };
  inTransit: {
    protocol: 'TLS 1.2+';
    cipherSuites: string[];
    certificateValidation: 'strict';
  };
  backup: {
    encrypted: true;
    keyStoredSeparately: true;
    testedRecovery: boolean;
  };
}

const hipaaEncryptionStandard: EncryptionConfig = {
  atRest: {
    algorithm: 'AES-256-GCM',
    keyManagement: 'AWS KMS',
    keyRotationDays: 90,
  },
  inTransit: {
    protocol: 'TLS 1.2+',
    cipherSuites: ['TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384'],
    certificateValidation: 'strict',
  },
  backup: {
    encrypted: true,
    keyStoredSeparately: true,
    testedRecovery: true,
  },
};
```

---

## SOC 2

### Type I vs Type II

| Aspect | Type I | Type II |
|--------|--------|---------|
| **Focus** | Design of controls | Design + operating effectiveness |
| **Time Period** | Point in time | Minimum 6 months |
| **Assurance** | Controls exist | Controls work as intended |
| **Use Case** | Vendor onboarding, quick validation | Ongoing trust, enterprise sales |
| **Cost** | Lower | Higher |
| **Frequency** | Annual | Annual |

### Trust Services Criteria (TSC)

```typescript
// soc2-criteria.ts
enum TrustServiceCriteria {
  SECURITY = 'CC6.1',      // Logical and physical access controls
  AVAILABILITY = 'A1.2',   // System availability for operation and use
  PROCESSING_INTEGRITY = 'PI1.3', // Complete, valid, accurate, timely processing
  CONFIDENTIALITY = 'C1.1', // Designation of confidential information
  PRIVACY = 'P1.1',        // Collection, use, retention, disposal of personal info
}

interface SOC2Control {
  id: string;
  criteria: TrustServiceCriteria;
  description: string;
  owner: string;
  frequency: 'continuous' | 'daily' | 'weekly' | 'monthly' | 'quarterly' | 'annual';
  automated: boolean;
  evidenceType: 'screenshot' | 'log' | 'report' | 'document' | 'config';
  evidenceLocation: string;
  testedBy: string;
  testDate: Date;
  result: 'pass' | 'fail' | 'exception';
  exceptions: string[];
}
```

### Audit Preparation Checklist

```typescript
// soc2-preparation.ts
const soc2Type2Preparation = {
  6_months_before: [
    'Define scope (which TSC)',
    'Identify systems in scope',
    'Document all policies',
    'Implement access control review process',
    'Enable comprehensive logging',
  ],
  3_months_before: [
    'Begin collecting evidence continuously',
    'Conduct internal gap assessment',
    'Remediate identified deficiencies',
    'Train employees on policies',
    'Document change management procedures',
  ],
  1_month_before: [
    'Engage auditor',
    'Prepare evidence repository',
    'Conduct mock audit',
    'Finalize policy documentation',
    'Review prior exceptions',
  ],
  during_audit: [
    'Provide evidence within 24-48 hours',
    'Be available for interviews',
    'Clarify any control gaps found',
    'Document management responses',
  ],
};
```

### Evidence Collection

```typescript
// evidence-collection.ts
interface EvidenceItem {
  controlId: string;
  evidenceType: 'automated' | 'manual';
  source: string;              // System, file, screenshot
  collectedAt: Date;
  collector: string;
  hash: string;              // SHA-256 for integrity
  retentionEndDate: Date;    // Typically 7 years for SOC 2
  metadata: {
    system: string;
    environment: 'production' | 'staging';
    version: string;
  };
}

async function collectEvidence(control: SOC2Control): Promise<EvidenceItem> {
  const evidence = await gatherEvidence(control);
  const hash = calculateSHA256(JSON.stringify(evidence));

  return {
    controlId: control.id,
    evidenceType: control.automated ? 'automated' : 'manual',
    source: evidence.source,
    collectedAt: new Date(),
    collector: 'compliance-system',
    hash,
    retentionEndDate: new Date(Date.now() + 7 * 365 * 24 * 60 * 60 * 1000),
    metadata: evidence.metadata,
  };
}
```

---

## PCI-DSS

### Cardholder Data Environment (CDE)

```typescript
// pci-dss-scope.ts
interface CardholderData {
  primaryAccountNumber: string; // PAN - must be encrypted or tokenized
  cardholderName: string;       // Can be stored if needed
  expirationDate: string;       // Can be stored if needed
  serviceCode: string;          // Can be stored if needed
  // NEVER STORE: Full magnetic stripe, CVV/CVC, PIN
}

interface PCIComplianceScope {
  scope: 'CDE' | 'connected' | 'out_of_scope';
  networkSegmentation: boolean;
  dataFlows: DataFlow[];
  systems: System[];
}

interface DataFlow {
  source: string;
  destination: string;
  dataElements: string[];
  encryption: 'TLS' | 'IPSec' | 'none';
  network: 'internal' | 'public';
}
```

### Network Segmentation

```typescript
// network-segmentation.ts
const pciNetworkArchitecture = {
  zones: [
    {
      name: 'Public Zone',
      cidr: '0.0.0.0/0',
      access: 'untrusted',
      controls: ['WAF', 'DDoS protection', 'TLS termination'],
    },
    {
      name: 'DMZ',
      cidr: '10.0.1.0/24',
      access: 'semi-trusted',
      controls: ['Firewall', 'IDS/IPS'],
    },
    {
      name: 'CDE',
      cidr: '10.0.2.0/24',
      access: 'highly restricted',
      controls: [
        'Firewall deny-all by default',
        'Two-factor authentication',
        'Logging and monitoring',
        'Vulnerability scanning',
        'File integrity monitoring',
      ],
    },
  ],
  rules: [
    'No direct access from Public to CDE',
    'All CDE access must go through DMZ',
    'Admin access to CDE requires jump box',
    'All CDE traffic encrypted',
  ],
};
```

### Vulnerability Scanning

```typescript
// vulnerability-management.ts
interface VulnerabilityScan {
  scanId: string;
  target: string;
  scanType: 'internal' | 'external' | 'ASV';
  scanner: 'Qualys' | 'Rapid7' | 'Tenable';
  findings: Finding[];
  scanDate: Date;
  nextScanDue: Date;
  approvedBy: string;
}

interface Finding {
  severity: 'critical' | 'high' | 'medium' | 'low' | 'informational';
  cveId: string;
  cvssScore: number;
  remediation: string;
  remediationDeadline: Date;
  status: 'open' | 'in_progress' | 'remediated' | 'accepted_risk';
  evidenceOfRemediation: string;
}

const pciScanningRequirements = {
  external: {
    frequency: 'Quarterly',
    requirement: '11.3.2',
    provider: 'ASV (Approved Scanning Vendor)',
  },
  internal: {
    frequency: 'Quarterly',
    requirement: '11.3.2',
    provider: 'Internal or qualified third party',
  },
  wireless: {
    frequency: 'Quarterly (if wireless in CDE)',
    requirement: '11.2.3',
  },
  penetration: {
    frequency: 'Annual (at minimum)',
    requirement: '11.3.1, 11.3.2',
  },
};
```

---

## Data Retention

### Policies by Data Type

```typescript
// data-retention-policy.ts
interface RetentionPolicy {
  dataType: string;
  retentionPeriod: string;
  legalBasis: string;
  trigger: 'creation' | 'last_activity' | 'account_closure' | 'consent_withdrawal';
  action: 'delete' | 'anonymize' | 'archive';
  exceptions: string[];
  autoEnforced: boolean;
}

const retentionPolicies: RetentionPolicy[] = [
  {
    dataType: 'user_account_data',
    retentionPeriod: '7 years after account closure',
    legalBasis: 'legitimate_interest',
    trigger: 'account_closure',
    action: 'delete',
    exceptions: ['legal_hold', 'tax_obligation'],
    autoEnforced: true,
  },
  {
    dataType: 'transaction_logs',
    retentionPeriod: '7 years',
    legalBasis: 'legal_obligation',
    trigger: 'creation',
    action: 'archive',
    exceptions: ['fraud_investigation'],
    autoEnforced: true,
  },
  {
    dataType: 'marketing_preferences',
    retentionPeriod: '2 years after last activity',
    legalBasis: 'consent',
    trigger: 'last_activity',
    action: 'delete',
    exceptions: [],
    autoEnforced: true,
  },
  {
    dataType: 'session_logs',
    retentionPeriod: '90 days',
    legalBasis: 'legitimate_interest',
    trigger: 'creation',
    action: 'delete',
    exceptions: ['security_incident'],
    autoEnforced: true,
  },
  {
    dataType: 'audit_logs',
    retentionPeriod: '7 years',
    legalBasis: 'legal_obligation',
    trigger: 'creation',
    action: 'archive',
    exceptions: ['compliance_review'],
    autoEnforced: true,
  },
];
```

### Automated Deletion

```typescript
// automated-deletion.ts
import { CronJob } from 'cron';

class DataRetentionEnforcer {
  async enforceRetentionPolicies(): Promise<DeletionReport> {
    const policies = await this.getRetentionPolicies();
    const report: DeletionReport = { deleted: 0, archived: 0, errors: [] };

    for (const policy of policies) {
      try {
        const expiredRecords = await this.findExpiredRecords(policy);

        for (const record of expiredRecords) {
          // Check for legal hold
          const hasLegalHold = await this.checkLegalHold(record);
          if (hasLegalHold) continue;

          if (policy.action === 'delete') {
            await this.deleteRecord(record, policy);
            report.deleted++;
          } else if (policy.action === 'anonymize') {
            await this.anonymizeRecord(record);
            report.deleted++;
          } else if (policy.action === 'archive') {
            await this.archiveRecord(record);
            report.archived++;
          }

          await this.logDeletion(record, policy);
        }
      } catch (error) {
        report.errors.push({ policy: policy.dataType, error: error.message });
      }
    }

    return report;
  }

  async deleteRecord(record: any, policy: RetentionPolicy): Promise<void> {
    // Cascade delete to all related personal data
    await this.db.$transaction(async (tx) => {
      await tx.userData.deleteMany({ where: { userId: record.userId } });
      await tx.activityLog.deleteMany({ where: { userId: record.userId } });
      await tx.user.delete({ where: { id: record.userId } });
    });
  }

  async checkLegalHold(record: any): Promise<boolean> {
    const holds = await this.db.legalHold.findMany({
      where: {
        userId: record.userId,
        active: true,
        expiresAt: { gt: new Date() },
      },
    });
    return holds.length > 0;
  }
}

// Run nightly at 2 AM
new CronJob('0 2 * * *', async () => {
  const enforcer = new DataRetentionEnforcer();
  await enforcer.enforceRetentionPolicies();
});
```

---

## Right to Erasure

### Cascade Deletion Strategy

```typescript
// erasure-service.ts
interface ErasureRequest {
  id: string;
  userId: string;
  requestedAt: Date;
  status: 'pending' | 'in_progress' | 'completed' | 'rejected';
  reason: 'user_request' | 'gdpr' | 'ccpa' | 'legal';
  scope: 'full' | 'partial';
  exceptions: string[]; // Legal holds, regulatory requirements
  completedAt: Date | null;
  verifiedBy: string | null;
}

class ErasureService {
  async processErasure(request: ErasureRequest): Promise<void> {
    await this.updateRequestStatus(request.id, 'in_progress');

    const deletionOrder = [
      'cache_entries',
      'session_data',
      'search_history',
      'activity_logs',
      'user_preferences',
      'user_content',
      'user_profile',
      'user_account',
    ];

    for (const table of deletionOrder) {
      await this.deleteFromTable(table, request.userId);
      await this.logDeletionStep(request.id, table);
    }

    // Publish anonymization event for analytics
    await this.eventBus.publish('user.erasure.completed', {
      userId: hashUserId(request.userId), // Anonymized
      completedAt: new Date(),
    });

    await this.updateRequestStatus(request.id, 'completed');
  }

  async deleteFromTable(table: string, userId: string): Promise<void> {
    // Use soft delete for audit trail, then hard delete after 30 days
    await this.db[table].updateMany({
      where: { userId },
      data: {
        deletedAt: new Date(),
        deletedBy: 'erasure_service',
        personalData: null, // Nullify personal data immediately
      },
    });
  }
}
```

### Soft Delete vs Hard Delete

```typescript
// deletion-strategies.ts
interface DeletionStrategy {
  type: 'soft' | 'hard' | 'anonymize';
  useCase: string;
  implementation: string;
  recovery: 'possible' | 'impossible' | 'partial';
  auditTrail: 'full' | 'metadata_only' | 'none';
}

const deletionStrategies: DeletionStrategy[] = [
  {
    type: 'soft',
    useCase: 'User-initiated deletion, 30-day grace period',
    implementation: 'Set deletedAt, hide from queries, allow recovery',
    recovery: 'possible',
    auditTrail: 'full',
  },
  {
    type: 'hard',
    useCase: 'GDPR erasure request, after grace period',
    implementation: 'DELETE from database, cascade to related tables',
    recovery: 'impossible',
    auditTrail: 'metadata_only',
  },
  {
    type: 'anonymize',
    useCase: 'Analytics data, regulatory retention requirements',
    implementation: 'Replace PII with hash, keep aggregate data',
    recovery: 'partial',
    auditTrail: 'metadata_only',
  },
];
```

---

## Data Portability

### Export Formats & API

```typescript
// data-export-service.ts
enum ExportFormat {
  JSON = 'json',
  CSV = 'csv',
  XML = 'xml',
  PDF = 'pdf',
}

interface ExportRequest {
  id: string;
  userId: string;
  format: ExportFormat;
  dataCategories: string[];
  requestedAt: Date;
  status: 'pending' | 'generating' | 'ready' | 'expired';
  downloadUrl: string | null;
  expiresAt: Date | null;
  sizeBytes: number | null;
}

class DataExportService {
  async generateExport(request: ExportRequest): Promise<ExportResult> {
    const data = await this.gatherUserData(request.userId, request.dataCategories);
    const formatted = await this.formatData(data, request.format);
    const encrypted = await this.encryptExport(formatted, request.userId);

    const url = await this.uploadToSecureStorage(encrypted);

    return {
      downloadUrl: url,
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days
      sizeBytes: encrypted.length,
    };
  }

  async gatherUserData(userId: string, categories: string[]): Promise<StructuredData> {
    const data: StructuredData = {
      exportMetadata: {
        generatedAt: new Date().toISOString(),
        formatVersion: '1.0',
        dataController: 'Company Name',
        dpoContact: 'dpo@company.com',
      },
      categories: {},
    };

    if (categories.includes('profile')) {
      data.categories.profile = await this.db.user.findUnique({
        where: { id: userId },
        select: { id: true, email: true, name: true, createdAt: true },
      });
    }

    if (categories.includes('activity')) {
      data.categories.activity = await this.db.activityLog.findMany({
        where: { userId },
        select: { action: true, timestamp: true, metadata: true },
      });
    }

    if (categories.includes('preferences')) {
      data.categories.preferences = await this.db.preference.findMany({
        where: { userId },
      });
    }

    return data;
  }

  async formatData(data: StructuredData, format: ExportFormat): Promise<string> {
    switch (format) {
      case ExportFormat.JSON:
        return JSON.stringify(data, null, 2);
      case ExportFormat.CSV:
        return this.convertToCSV(data);
      case ExportFormat.XML:
        return this.convertToXML(data);
      default:
        throw new Error(`Unsupported format: ${format}`);
    }
  }

  private convertToCSV(data: StructuredData): string {
    // Flatten nested objects for CSV export
    const rows: Record<string, string>[] = [];
    for (const [category, items] of Object.entries(data.categories)) {
      if (Array.isArray(items)) {
        for (const item of items) {
          rows.push({ category, ...this.flattenObject(item) });
        }
      } else {
        rows.push({ category, ...this.flattenObject(items) });
      }
    }
    return this.jsonToCSV(rows);
  }
}
```

---

## Consent Management

### Granular Consent

```typescript
// granular-consent.ts
interface ConsentCategory {
  id: string;
  name: string;
  description: string;
  required: boolean;
  defaultValue: boolean;
  lawfulBasis: 'consent' | 'legitimate_interest' | 'legal_obligation';
  purposes: string[];
  dataProcessed: string[];
  thirdParties: string[];
}

const consentCategories: ConsentCategory[] = [
  {
    id: 'essential',
    name: 'Essential',
    description: 'Required for core service functionality',
    required: true,
    defaultValue: true,
    lawfulBasis: 'legal_obligation',
    purposes: ['account_management', 'security', 'fraud_prevention'],
    dataProcessed: ['email', 'password_hash', 'ip_address'],
    thirdParties: [],
  },
  {
    id: 'analytics',
    name: 'Analytics',
    description: 'Helps us improve our services',
    required: false,
    defaultValue: false,
    lawfulBasis: 'consent',
    purposes: ['usage_analysis', 'feature_improvement'],
    dataProcessed: ['page_views', 'clicks', 'device_info'],
    thirdParties: ['Google Analytics', 'Mixpanel'],
  },
  {
    id: 'marketing',
    name: 'Marketing',
    description: 'Personalized offers and recommendations',
    required: false,
    defaultValue: false,
    lawfulBasis: 'consent',
    purposes: ['personalized_ads', 'email_marketing', 'retargeting'],
    dataProcessed: ['browsing_history', 'purchase_history', 'preferences'],
    thirdParties: ['Facebook', 'Google Ads'],
  },
  {
    id: 'third_party_sharing',
    name: 'Third-Party Sharing',
    description: 'Share data with trusted partners',
    required: false,
    defaultValue: false,
    lawfulBasis: 'consent',
    purposes: ['partner_services', 'integrations'],
    dataProcessed: ['profile_data', 'activity_data'],
    thirdParties: ['Partner A', 'Partner B'],
  },
];
```

### Preference Center

```typescript
// preference-center.ts
class PreferenceCenter {
  async getUserPreferences(userId: string): Promise<ConsentState> {
    const consents = await this.db.consent.findMany({
      where: { userId },
      orderBy: { timestamp: 'desc' },
      distinct: ['purpose'],
    });

    const preferences: ConsentState = {};
    for (const category of consentCategories) {
      const consent = consents.find(c => c.purpose === category.id);
      preferences[category.id] = {
        granted: consent?.granted ?? category.defaultValue,
        timestamp: consent?.timestamp ?? null,
        version: consent?.version ?? null,
        required: category.required,
      };
    }

    return preferences;
  }

  async updatePreferences(userId: string, updates: Record<string, boolean>): Promise<void> {
    for (const [categoryId, granted] of Object.entries(updates)) {
      const category = consentCategories.find(c => c.id === categoryId);
      if (!category) throw new Error(`Invalid category: ${categoryId}`);
      if (category.required && !granted) {
        throw new Error(`Cannot revoke required consent: ${categoryId}`);
      }

      await this.consentManager.recordConsent(userId, categoryId, granted, {
        channel: 'preference_center',
        version: '2.0',
      });

      // If withdrawing, trigger data deletion for that purpose
      if (!granted) {
        await this.triggerPurposeSpecificDeletion(userId, categoryId);
      }
    }
  }
}
```

---

## Privacy by Design

### Data Minimization

```typescript
// data-minimization.ts
interface DataMinimizationRule {
  field: string;
  collect: boolean;
  purpose: string;
  lawfulBasis: string;
  retention: string;
  validation: 'required' | 'optional' | 'conditional';
  pseudonymize: boolean;
}

const userRegistrationFields: DataMinimizationRule[] = [
  { field: 'email', collect: true, purpose: 'authentication', lawfulBasis: 'contract', retention: 'account_lifetime', validation: 'required', pseudonymize: false },
  { field: 'password', collect: true, purpose: 'authentication', lawfulBasis: 'contract', retention: 'account_lifetime', validation: 'required', pseudonymize: true }, // Hash only
  { field: 'name', collect: true, purpose: 'personalization', lawfulBasis: 'consent', retention: 'account_lifetime', validation: 'optional', pseudonymize: false },
  { field: 'phone', collect: false, purpose: '2fa', lawfulBasis: 'consent', retention: 'account_lifetime', validation: 'conditional', pseudonymize: false },
  { field: 'birthdate', collect: false, purpose: 'age_verification', lawfulBasis: 'legal_obligation', retention: 'account_lifetime', validation: 'optional', pseudonymize: true },
  { field: 'address', collect: false, purpose: 'shipping', lawfulBasis: 'contract', retention: 'transaction_lifetime', validation: 'conditional', pseudonymize: false },
];

// Only collect fields marked for collection
function collectRegistrationData(input: any): any {
  const collected: any = {};
  for (const rule of userRegistrationFields) {
    if (rule.collect && input[rule.field] !== undefined) {
      collected[rule.field] = input[rule.field];
    }
  }
  return collected;
}
```

### Default Privacy Settings

```typescript
// default-privacy.ts
const defaultPrivacySettings = {
  profileVisibility: 'private',        // Not public by default
  searchIndexing: false,             // Not searchable by default
  dataSharing: false,                  // No third-party sharing by default
  analyticsConsent: false,           // Analytics off by default
  marketingConsent: false,           // Marketing off by default
  locationTracking: false,           // Location off by default
  automaticDataDeletion: true,       // Auto-delete enabled by default
  cookiePreferences: {
    essential: true,                  // Cannot be disabled
    functional: false,
    analytics: false,
    marketing: false,
  },
};

class PrivacySettingsService {
  async createDefaultSettings(userId: string): Promise<void> {
    await this.db.privacySettings.create({
      data: {
        userId,
        ...defaultPrivacySettings,
        createdAt: new Date(),
      },
    });
  }
}
```

---

## Cross-Border Data Transfer

### Transfer Mechanisms

```typescript
// data-transfer-mechanisms.ts
interface TransferMechanism {
  name: string;
  from: string;
  to: string;
  legalBasis: string;
  requirements: string[];
  documentation: string[];
  risks: string[];
}

const transferMechanisms: TransferMechanism[] = [
  {
    name: 'Adequacy Decision',
    from: 'EU',
    to: 'Adequate country (e.g., UK, Japan, S. Korea)',
    legalBasis: 'GDPR Article 45',
    requirements: ['Country recognized by EU Commission as adequate'],
    documentation: ['None required beyond standard records'],
    risks: ['Adequacy decision can be revoked'],
  },
  {
    name: 'Standard Contractual Clauses (SCCs)',
    from: 'EU',
    to: 'Non-adequate country',
    legalBasis: 'GDPR Article 46',
    requirements: ['Signed EU Commission SCCs', 'Transfer impact assessment (TIA)', 'Supplementary measures if needed'],
    documentation: ['Signed SCCs', 'TIA report', 'Implementation evidence'],
    risks: ['May need supplementary measures for sensitive transfers', 'Court scrutiny'],
  },
  {
    name: 'Binding Corporate Rules (BCRs)',
    from: 'EU',
    to: 'Group companies globally',
    legalBasis: 'GDPR Article 46',
    requirements: ['Approved by lead DPA', 'Legally binding within group', 'Data protection built-in'],
    documentation: ['BCR document', 'Approval letter', 'Training records'],
    risks: ['Long approval process (1-2 years)', 'Limited to intra-group transfers'],
  },
  {
    name: 'Data Localization',
    from: 'Any',
    to: 'Same jurisdiction',
    legalBasis: 'National law (e.g., China PIPL, Russia data law)',
    requirements: ['Data stored in local jurisdiction', 'Local processing'],
    documentation: ['Architecture docs', 'Data mapping'],
    risks: ['Increased costs', 'Operational complexity', 'Disaster recovery limitations'],
  },
];
```

---

## Audit Logging

### Comprehensive Audit Trail

```typescript
// audit-logging.ts
import { PrismaClient } from '@prisma/client';

interface AuditLogEntry {
  id: string;
  timestamp: Date;
  actor: {
    userId: string | null;
    type: 'user' | 'system' | 'api' | 'admin';
    ipAddress: string;
    userAgent: string | null;
    sessionId: string | null;
  };
  action: {
    type: 'create' | 'read' | 'update' | 'delete' | 'export' | 'login' | 'logout' | 'consent' | 'erasure';
    resource: string;
    resourceId: string;
  };
  context: {
    endpoint: string;
    method: string;
    requestId: string;
    correlationId: string;
  };
  before: Record<string, any> | null;   // For update/delete
  after: Record<string, any> | null;    // For create/update
  result: 'success' | 'failure' | 'denied';
  reason: string | null;                 // For denials/failures
  severity: 'info' | 'warning' | 'critical';
}

class AuditLogger {
  private db: PrismaClient;
  private readonly IMMUTABLE = true;

  async log(entry: Omit<AuditLogEntry, 'id'>): Promise<void> {
    const logEntry: AuditLogEntry = {
      ...entry,
      id: generateUUID(),
    };

    // Write to append-only audit table
    await this.db.auditLog.create({
      data: {
        ...logEntry,
        actor: JSON.stringify(logEntry.actor),
        action: JSON.stringify(logEntry.action),
        context: JSON.stringify(logEntry.context),
        before: logEntry.before ? JSON.stringify(logEntry.before) : null,
        after: logEntry.after ? JSON.stringify(logEntry.after) : null,
      },
    });

    // Also send to SIEM for real-time monitoring
    await this.siem.send({
      index: 'audit-logs',
      body: logEntry,
    });
  }

  async logDataAccess(userId: string, resource: string, resourceId: string, action: string): Promise<void> {
    await this.log({
      timestamp: new Date(),
      actor: {
        userId,
        type: 'user',
        ipAddress: this.context.ipAddress,
        userAgent: this.context.userAgent,
        sessionId: this.context.sessionId,
      },
      action: {
        type: action as any,
        resource,
        resourceId,
      },
      context: {
        endpoint: this.context.endpoint,
        method: this.context.method,
        requestId: this.context.requestId,
        correlationId: this.context.correlationId,
      },
      before: null,
      after: null,
      result: 'success',
      reason: null,
      severity: 'info',
    });
  }
}

// Middleware to auto-log all data access
export function auditMiddleware(req: Request, res: Response, next: NextFunction) {
  const originalJson = res.json;
  res.json = function(body) {
    if (req.path.startsWith('/api/users') || req.path.startsWith('/api/patients')) {
      auditLogger.logDataAccess(
        req.user?.id,
        req.path,
        req.params.id || 'list',
        req.method.toLowerCase()
      );
    }
    return originalJson.call(this, body);
  };
  next();
}
```

### Immutable Audit Storage

```typescript
// immutable-logs.ts
interface ImmutableLogConfig {
  storage: 'append_only_db' | 'blockchain' | 'WORM_storage' | 'paper_trail';
  tamperDetection: boolean;
  retentionYears: number;
  accessControl: 'dpo_only' | 'compliance_team' | 'auditor';
  encryption: 'AES-256' | 'HSM';
}

const auditConfig: ImmutableLogConfig = {
  storage: 'append_only_db',
  tamperDetection: true,
  retentionYears: 7,
  accessControl: 'dpo_only',
  encryption: 'HSM',
};

// Use database triggers to prevent UPDATE/DELETE on audit table
const auditTableTrigger = `
  CREATE TRIGGER audit_immutable
  BEFORE UPDATE OR DELETE ON audit_logs
  FOR EACH ROW
  BEGIN
    RAISE EXCEPTION 'Audit logs are immutable and cannot be modified or deleted';
  END;
`;
```

---

## Compliance Checklists

### GDPR Checklist

```typescript
const gdprChecklist = {
  governance: [
    '[ ] Appointed DPO (if required)',
    '[ ] Data processing register maintained',
    '[ ] Privacy policy published and up-to-date',
    '[ ] Data protection impact assessments (DPIAs) for high-risk processing',
    '[ ] Data breach response plan documented',
    '[ ] 72-hour breach notification process tested',
  ],
  rights: [
    '[ ] Subject access request (SAR) process defined (< 30 days)',
    '[ ] Data portability mechanism (JSON/CSV export)',
    '[ ] Right to erasure workflow implemented',
    '[ ] Right to rectification process defined',
    '[ ] Right to restriction process defined',
    '[ ] Automated decision-making opt-out available',
  ],
  consent: [
    '[ ] Consent is freely given, specific, informed, unambiguous',
    '[ ] Granular consent options available',
    '[ ] Consent withdrawal as easy as giving consent',
    '[ ] Consent records maintained with timestamp and version',
    '[ ] No pre-ticked boxes or implied consent',
  ],
  security: [
    '[ ] Pseudonymization/encryption of personal data',
    '[ ] Ongoing confidentiality, integrity, availability',
    '[ ] Regular testing and evaluation of security measures',
    '[ ] Incident response plan including data breach',
  ],
  third_parties: [
    '[ ] Data processing agreements (DPAs) with all processors',
    '[ ] Cross-border transfer mechanisms documented (SCCs/BCRs)',
    '[ ] Sub-processor list published and maintained',
  ],
};
```

### HIPAA Checklist

```typescript
const hipaaChecklist = {
  administrative: [
    '[ ] Security management process (risk analysis, risk management)',
    '[ ] Assigned security responsibilities',
    '[ ] Workforce security (authorization, termination)',
    '[ ] Information access management',
    '[ ] Security awareness and training program',
    '[ ] Security incident procedures',
    '[ ] Contingency plan (data backup, disaster recovery)',
    '[ ] Business associate agreements (BAAs) executed',
  ],
  physical: [
    '[ ] Facility access controls (locks, badges, cameras)',
    '[ ] Workstation use and security policies',
    '[ ] Device and media controls (inventory, disposal)',
  ],
  technical: [
    '[ ] Access control (unique user IDs, emergency access)',
    '[ ] Audit controls (logging, monitoring)',
    '[ ] Integrity controls (checksums, digital signatures)',
    '[ ] Person/entity authentication',
    '[ ] Transmission security (TLS, VPN)',
  ],
  documentation: [
    '[ ] Policies and procedures written',
    '[ ] Documentation retained for 6 years',
    '[ ] Regular review and update schedule',
  ],
};
```

### SOC 2 Type II Checklist

```typescript
const soc2Type2Checklist = {
  before_audit: [
    '[ ] Define scope (Security + relevant TSC)',
    '[ ] Document all controls with owners',
    '[ ] Implement control monitoring (automated where possible)',
    '[ ] Begin evidence collection (6-month minimum)',
    '[ ] Conduct gap assessment and remediate',
    '[ ] Train employees on policies',
  ],
  during_audit: [
    '[ ] Provide evidence within 48 hours of request',
    '[ ] Schedule management interviews',
    '[ ] Walk through key controls with auditors',
    '[ ] Document any exceptions with compensating controls',
    '[ ] Review draft report for factual accuracy',
  ],
  after_audit: [
    '[ ] Address any deficiencies noted',
    '[ ] Implement continuous monitoring',
    '[ ] Schedule next year\'s audit',
    '[ ] Share report with key customers under NDA',
  ],
};
```

---

## Summary

| Regulation | Key Focus | Primary Rights/Requirements | Penalty for Non-Compliance |
|------------|-----------|----------------------------|--------------------------|
| **GDPR** | Data subject rights | Access, erasure, portability, consent | Up to 4% global revenue or €20M |
| **HIPAA** | PHI protection | Security safeguards, BAAs, breach notification | Up to $1.5M per violation category/year |
| **SOC 2** | Service organization controls | Security, availability, processing integrity | Reputational, contractual |
| **PCI-DSS** | Cardholder data protection | Encryption, segmentation, scanning | Fines, loss of processing ability |

Compliance is not a one-time project but an ongoing operational commitment. Integrate controls into development workflows, automate evidence collection, and conduct regular internal audits to maintain readiness.
