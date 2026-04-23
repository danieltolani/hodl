export function parseGlobusEmail({ subject, body, date }) {
  return {
    amount: extractAmount(subject, body),
    narration: extractNarration(body),
    date: formatDate(date),
  };
}

function extractAmount(subject, body) {
  // Primary: subject bracket — "Globus Bank Transaction Alert [Debit: NGN 6,800]"
  const subjectMatch = subject.match(/\[Debit:\s*NGN\s*([\d,]+(?:\.\d+)?)\]/i);
  if (subjectMatch) return parseFloat(subjectMatch[1].replace(/,/g, ''));

  // Fallback: body line — "Transaction Amount -NGN 6,800" or "-NGN6800"
  const bodyMatch = body.match(/Transaction\s+Amount[\s\S]{0,15}-?\s*NGN\s*([\d,]+(?:\.\d+)?)/i);
  if (bodyMatch) return parseFloat(bodyMatch[1].replace(/,/g, ''));

  return null;
}

// Truncate the body at the first "next section" marker so regexes don't overrun
const STOP = /\s+(?:Transaction Type|Available Balance|Ledger Balance|Value Date)/i;

function extractNarration(body) {
  // Globus Bank reference format: {acct}/FT/MB/{memo}/{recipient}
  // e.g. "3734917328/FT/MB/Eggs/GCM SUPERMARKET - OGOCH"
  const globusMatch = body.match(
    /\d{7,}\/(?:charge\d+\/)?(?:FT|POS|WEB)\/(?:MB|IB|WB)\/([^/\s][^/]*)\/([^/]+?)(?=\s+Transaction Type|\s+Available|\s+Ledger|\s+Value Date|$)/i
  );
  if (globusMatch) {
    const memo = globusMatch[1].trim();
    const recipient = globusMatch[2].trim();
    if (memo && recipient) return `${memo} → ${recipient}`;
    if (memo) return memo;
  }

  // Fallback: label-based patterns, capped before the next email section
  const stopIdx = body.search(STOP);
  const head = stopIdx > 0 ? body.slice(0, stopIdx) : body;

  const patterns = [
    /Narration[:\s]+(.+)/i,
    /Description[:\s]+(.+)/i,
    /Remark[:\s]+(.+)/i,
  ];
  for (const re of patterns) {
    const match = head.match(re);
    if (match) {
      const text = match[1].trim().replace(/\s+/g, ' ');
      if (text.length > 2) return text;
    }
  }

  return 'Debit Transaction';
}

function formatDate(dateStr) {
  const d = new Date(dateStr);
  if (isNaN(d.getTime())) return new Date().toISOString().split('T')[0];
  return d.toISOString().split('T')[0];
}
