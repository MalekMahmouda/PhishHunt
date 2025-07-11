#!/bin/bash

infile="$1"
outfile="report.txt"

if [[ ! -f "$infile" ]]; then
  echo "❌ File '$infile' not found. Try: ./phishhunt-live.sh sample.eml"
  exit 1
fi

# create a temp file
tmpfile=$(mktemp)

# redirect stdout to both screen and file
exec > >(tee "$outfile") 2>&1

echo ""
echo "📧 Email Analysis Report: $infile"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Extract headers
grep -E "^(From|To|Subject|Received):" "$infile" > headers.txt

# Extract domain
domain=$(grep -oP "(?<=@)[a-zA-Z0-9.-]+" headers.txt | head -n1)
echo "🌐 Extracted Domain: $domain"

# WHOIS
echo ""
echo "🔍 WHOIS Lookup:"
whois_out=$(whois "$domain" 2>/dev/null)
creation_date=$(echo "$whois_out" | grep -iE "Creation Date|Created On" | head -n1)
registrar=$(echo "$whois_out" | grep -i "Registrar:" | head -n1)

[[ -z "$creation_date" ]] && creation_date="❌ Not available"
[[ -z "$registrar" ]] && registrar="❌ Not available"

echo "- Registrar: $registrar"
echo "- Creation Date: $creation_date"

# DNS
echo ""
echo "🧠 DNS Lookup:"
a_record=$(dig +short A "$domain" | head -n1)
mx_record=$(dig +short MX "$domain" | head -n1)

[[ -z "$a_record" ]] && a_record="❌ Not found"
[[ -z "$mx_record" ]] && mx_record="❌ Not found"

echo "- A Record: $a_record"
echo "- MX Record: $mx_record"

# Extract links
echo ""
echo "🔗 URLs found in email:"
grep -oP "https?://[^\s'\"<>()]+" "$infile" > urls.txt

# Fallback for Markdown-style links
if [[ ! -s urls.txt ]]; then
  grep -oP "\(https?://[^\s\)]+?\)" "$infile" | tr -d '()' >> urls.txt
fi

if [[ ! -s urls.txt ]]; then
  echo "❌ No URLs found"
else
  cat urls.txt
fi

# HTTP Status
echo ""
echo "🌍 HTTP Status Check:"
while read url; do
  if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    status=$(curl -I --max-time 5 "$url" 2>/dev/null | head -n1)
    [[ -z "$status" ]] && status="❌ No response"
  else
    status="⚠️ No internet connection"
  fi
  echo "$url → $status"
done < urls.txt

# Final risk check
echo ""
echo "🛡️ Final Risk Evaluation:"
if [[ "$creation_date" == *2025* ]] || [[ "$domain" == *login* ]] || grep -q "xyz" urls.txt; then
  echo "⚠️⚠️ Warning: This email appears to be phishing"
else
  echo "✅ No clear phishing indicators... manual review recommended"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📄 Report saved to: $outfile"
