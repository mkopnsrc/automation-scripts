# My Automation Scripts Repository

This repository contains a collection of custom scripts for managing Servers, AWS, Google CloudDNS, and other services. The scripts are written in various languages, including Bash, Python, Powershell, and etc.

## My Scripts Naming Conventions

- Uses meaningful names that describe the purpose of the script.
- Uses lowercase letters for all script names.
- Uses underscores (_) to separate words in the script name.
- Includes the appropriate file extension for the script language (e.g. `.sh` for bash scripts, `.py` for Python scripts, `.ps1` for Powershell scripts).
- Avoided using special characters in script names.

## Script Header Types

### Bash
`#!/bin/bash`

### Python
`#!/usr/bin/env python3`

### Ruby
`#!/usr/bin/env ruby`

### Perl
`#!/usr/bin/perl`

### Powershell 5
`#Requires –Version 5.1`

### Powershell 7
`#Requires –Version 7`


## Multi-line Comments Header

### Bash

```
: <<'#HEADER_COMMENTS'
ScriptName: [Name of the script]
Created: 2024-06-25
Updated: 2024-06-27
Version: 20240627 (For multiple iteration version format '20240307.XX')

Author: [Your Name]

Description:
Requirements:
Functionality:
Usage:
#HEADER_COMMENTS
```

### Python

```
"""
ScriptName: [Name of the script]
Created: 2024-03-07
Updated: 2024-03-07
Version: 20240307 (For multiple iteration version format '20240307.XX')

Author: [Your Name]

Descriptions: script descriptions
Requirements: script requirements in terms of script parameters or arguments
Functionality:
Usage:
"""
```

### Powershell

```
<#
ScriptName: [Name of the script]
Created: 2024-03-07
Updated: 2024-03-07
Version: 20240307 (For multiple iteration version format '20240307.XX')

Author: [Your Name]

Descriptions: script descriptions
Requirements: script requirements in terms of script parameters or arguments
Functionality:
Usage:
#>
```

## Dependencies

List any dependencies or requirements (e.g., specific software versions, libraries) needed to run scripts.
Create a txt file with same name as your script name and include dependencies or requirements for scripts that requires external modules

## Security

Ensure that scripts are secure by following best practices for handling sensitive information and validating input data formats.

## Maintenance 

Regularly review and update your scripts to ensure they remain compatible with the latest technologies and best practices.

## Contributing

Feel free to contribute by adding your own scripts following the naming conventions mentioned above. Please ensure that your scripts are well-documented and include usage instructions.
