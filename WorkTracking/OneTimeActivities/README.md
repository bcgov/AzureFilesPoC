# One-Time Activities for Azure Files PoC

This directory contains documentation for one-time setup activities required for the Azure Files Proof of Concept project.

## Contents

- [RegisterApplicationInAzure.md](RegisterApplicationInAzure.md) - Steps to register an application in Azure AD for GitHub Actions authentication

## Purpose

These activities only need to be performed once during the project setup. They are typically prerequisites for other ongoing work and are documented here for reference.

## Process

For each one-time activity:

1. Follow the documented steps carefully **one at a time**
2. **Verify each step in the Azure portal or other relevant system before proceeding to the next step**
3. Record the completion date, status, and results in the document's Progress Tracking table
4. Uncomment the next step only after successfully completing the current step
5. Verify the entire activity was successful before proceeding with dependent tasks

## Security Considerations

Some of these activities involve creating security principals or managing credentials:

1. Always follow the principle of least privilege
2. Document all security-related changes completely
3. Validate each step before proceeding to ensure security controls are properly implemented
4. Record all verification steps performed
5. Follow the step-by-step approach to ensure nothing is missed

## Why the Step-by-Step Approach?

The step-by-step approach with verification between steps ensures:

1. **Security**: Each security change is verified before proceeding
2. **Auditability**: A clear record exists of what was done and when
3. **Error Prevention**: Problems are caught early rather than at the end of a long process
4. **Documentation**: The process is fully documented as you go
5. **Knowledge Transfer**: The process can be understood and replicated by others
