# autodig
Batch obtaining and verifying DNS record

autodig is currently in *alpha* development stage, it requires cleanup and [Feature Enhancement](#features-required)!

## Requirements
- You have a Linux System.
- You have dnsutils installed.

On Debian:
```bash
sudo apt-get install -y dnsutils
```

## Usage
Usage Example:

Create a query text file, namely query.txt, with format: _RType,FQDN_
```bash
A,google.com.
NS,google.com.
A,yahoo.com.
NS,yahoo.com.
```

Commit batch dns record lookup with autodig.sh, questions-and-answer pair will be created in *answers.txt*.
```bash
./autodig.sh 0 query.txt answers.txt
```

Use the questions-and-answer pair to check whether new DNS server records are in order.
```bash
./autodig.sh 1 answers.txt verification-report.txt
```

## Features Required
- FQDN checking
- IPv6 and IPv6 checking
- Any Suggestions?
