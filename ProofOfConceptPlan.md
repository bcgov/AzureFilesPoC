
# Azure Files PoC Plan

## 🔍 Problem Statement

The BC Government faces significant challenges with its current on-premises file storage infrastructure:

- **Escalating Costs**: Operating expenditures for storage hardware continue to rise, while operational expenses for maintenance and administration consume an increasing portion of the IT budget
- **Limited Optimization**: Current on-premises enterprise storage solution with additional tiering software leverage automated policies to move infrequently used data to cheaper cold storage, but those solutions have had challenges with cost per GB.  
- **Administrative Burden**: Technical staff spend excessive time on storage management rather than on higher-value services to citizens. Current solutions for automated tiering to cheaper storage have significant administrative overhead and additional storage requirements.
- **Capacity Constraints**: Meeting the growing demand for large media file storage requires frequent, costly expansions of on-premises systems
- **Data Growth Crisis**: Media content (video/audio evidence, public service recordings, etc.) continues to grow exponentially with no effective archival strategy

Recent improvements in Azure's Canadian service offerings have created new opportunities to leverage public cloud services while meeting rigorous security and compliance requirements. A cloud-first approach to file storage could deliver significant cost savings while improving service delivery and aligning with the BC Government's mandate for fiscal responsibility and efficient use of taxpayer resources

## 💡 Overview

This proof-of-concept will evaluate Azure Files as a hybrid storage solution that can potentially reduce the total cost of ownership for file storage while maintaining or enhancing security, compliance, and performance. By testing Azure Files with optional Azure Blob Storage integration, we aim to demonstrate a practical path toward:

- Significantly reduced storage costs through cloud economies of scale
- More effective storage lifecycle management 
- Enhanced data protection and security capabilities
- Improved operational efficiency and resource utilization
- Better management of media files with automated archival capabilities

This initiative aligns directly with the BC Government's Digital Framework principles, particularly "Service Modernization" and "Sustainable & Effective Use of Resources," while ensuring that ministry-specific security and compliance requirements are met or exceeded.

## 🎯 Objectives

Evaluate Azure Files (and optionally Azure Blob Storage with lifecycle management) for:

- Reducing operational and storage costs through cloud-based storage and automated tiering (cost reduction)
- Accommodating large media files (video/audio) with appropriate performance and accessibility (validate technical feasibility)
- Implementing advanced data lifecycle management with automated policies for tiering and archival (validate storage optimization)
- Enhancing reporting and auditability capabilities for data governance and cost management (improve accountability)
- Improving overall security posture and compliance with government standards (strengthen data protection)
- Demonstrating responsible stewardship of taxpayer resources (improve public value delivery)

## ✅ Azure Files PoC Architecture
See [Azure Files PoC Architecture Overview](ArchitectureOverview.md)

## ✅ Evaluation Criteria
### 1. File Access & Management
- Folder rename support
- Case sensitivity handling
- Real-time sync across clients (i.e. when one person adds, changes, or deletes a file, those changes are immediately visible to everyone else using the same shared folder—without needing to refresh, wait, or manually sync)
- Native SMB/UNC support
  - SMB is the protocol that lets you open shared folders like `\ServerName\SharedFolder` from File Explorer.
  - UNC paths are the format used to point to those shared folders (e.g., `\CourtServer\Evidence\Video1.mp4`).
- NTFS metadata preservation
  - Who owns the file (file owner)
  - Who can access it and what they can do (permissions)
  - When it was created, modified, or accessed (timestamps)
  - Special file attributes (like read-only, hidden, or system file)

### 2. Performance & Latency
- Upload/download speed for large files
- Real-time access for playback systems
- Stub hydration speed (if using File Sync). i.e. with File Sync, files that are stored in the cloud can appear on your local server as “stubs”—tiny placeholder files that look like the real thing but don’t take up space until you open them. Stub hydration is the process of downloading the full file from the cloud when someone tries to open or use it. This is important because if someone clicks on a video or audio file in court, it needs to start playing quickly. If hydration is slow, users experience delays, which can disrupt court proceedings or investigations.

### 3. Security & Compliance
- Active Directory integration
- NTFS permissions enforcement (ACL support). Can use same domain security groups in Azure Files.
- Antivirus/ransomware protection
- Audit logging (access tracking)
- Encryption (What are the specific requirements here? can we test them in the PoC?)

### 4. Backup & Recovery
- Snapshot support and rollback
- Azure Backup integration
- Encryption key management (BYOK/HSM). Being able to manage your own key (BYOK-bring your own key).

### 5. Tiering & Lifecycle Management
- Manual vs. automated tiering (Hot → Cool → Archive)
- Lifecycle rules for archival. Lifecycle rules are automated policies you set up in Azure (usually for Blob Storage) to move files to cheaper storage tiers based on how old or unused they are.
- Integration with Azure Blob Storage. Azure Blob Storage is designed for scalable, cost-effective storage of large files like video and audio. Integrating Azure Files with Blob Storage allows you to:
  - Move older or infrequently accessed files from Azure Files to Blob Storage (Cool or Archive tiers)
  - Use lifecycle rules to automate this movement and reduce costs
  - Store large volumes of evidence long-term without paying premium storage prices
- Cost savings from tiering

### 6. Reporting & Monitoring
- % of data in each tier (Hot, Cool, Archive)
- GB per tier over time
- Snapshot history and trends
- Alerts for stale data or tiering gaps
- Power BI dashboards or Azure Monitor views

### 7. Supportability & Cost Analysis
- Ease of setup and maintenance
- Total cost of ownership framework (detailed calculations to be maintained separately)
  - Storage costs by tier (Premium vs. Standard vs. Cool/Archive)
  - Transaction costs for typical workloads
  - Network egress charges
  - Backup and snapshot storage costs
  - Private endpoint and networking costs
- Cost optimization opportunities:
  - Savings from automated tiering
  - Reduction in on-premises infrastructure
  - Operational efficiency gains
  - Pay-as-you-go elasticity benefits
- 5-Year TCO comparison framework (on-premises vs. Azure Files)
  - Including hardware refresh cycles
  - Staff time allocation differences
  - Growth projections
- Risk assessment of vendor relationship impacts
  - Potential data center provider cost recovery mechanisms if storage revenue decreases
  - Contract review for hidden minimum commitments or tier pricing
  - Strategy for negotiating revised service agreements

## 🧪 Test Scenarios
| **Scenario** | **Goal** |
|--------------|----------|
| Upload 1GB+ video file | Measure upload speed, hydration time |
| Access file from multiple clients | Test real-time sync, concurrency |
| Apply NTFS permissions | Validate ACL enforcement, AD integration |
| Move file to Blob Archive | Test lifecycle automation, cost savings |
| Generate audit report | Validate access logging, traceability |
| Visualize tier distribution | Assess reporting capabilities |
| Access large files from Blob | Test playback performance |
| Rename non-empty folders | Confirm support and behavior |
| Trigger ransomware simulation | Test detection and recovery |
| Snapshot rollback | Validate backup and recovery |
| BYOK encryption test | Validate encryption key control |

## 📅 Timeline
| **Phase** | **Duration** | **Activities** |
|-----------|--------------|----------------|
| Planning |TBC | Define scope, assign roles, provision Azure resources |
| Implementation | TBC | Deploy Azure Files, File Sync, Blob Storage, configure networking |
| Testing | TBC | Execute test scenarios, collect metrics |
| Analysis | TBC | Compare results with current solutions, evaluate cost/performance |
| Reporting | TBC | Final report, recommendations, stakeholder presentation |


