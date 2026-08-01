import re
import math
from collections import Counter

STOPWORDS = {
    'i', 'me', 'my', 'myself', 'we', 'our', 'ours', 'ourselves', 'you', "you're", "you've", "you'll", "you'd",
    'your', 'yours', 'yourself', 'yourselves', 'he', 'him', 'his', 'himself', 'she', "she's", 'her', 'hers',
    'herself', 'it', "it's", 'its', 'itself', 'they', 'them', 'their', 'theirs', 'themselves', 'what', 'which',
    'who', 'whom', 'this', 'that', "that'll", 'these', 'those', 'am', 'is', 'are', 'was', 'were', 'be', 'been',
    'being', 'have', 'has', 'had', 'having', 'do', 'does', 'did', 'doing', 'a', 'an', 'the', 'and', 'but', 'if',
    'or', 'because', 'as', 'until', 'while', 'of', 'at', 'by', 'for', 'with', 'about', 'against', 'between',
    'into', 'through', 'during', 'before', 'after', 'above', 'below', 'to', 'from', 'up', 'down', 'in', 'out',
    'on', 'off', 'over', 'under', 'again', 'further', 'then', 'once', 'here', 'there', 'when', 'where', 'why',
    'how', 'all', 'any', 'both', 'each', 'few', 'more', 'most', 'other', 'some', 'such', 'no', 'nor', 'not',
    'only', 'own', 'same', 'so', 'than', 'too', 'very', 's', 't', 'can', 'will', 'just', 'don', "don't", 'should',
    "should've", 'now', 'd', 'll', 'm', 'o', 're', 've', 'y', 'ain', 'aren', "aren't", 'couldn', "couldn't",
    'didn', "didn't", 'doesn', "doesn't", 'hadn', "hadn't", 'hasn', "hasn't", 'haven', "haven't", 'isn', "isn't",
    'ma', 'mightn', "mightn't", 'mustn', "mustn't", 'needn', "needn't", 'shan', "shan't", 'shouldn', "shouldn't",
    'wasn', "wasn't", 'weren', "weren't", 'won', "won't", 'wouldn', "wouldn't"
}

CHUNKS = [
    {
        "id": "css_definition",
        "text": "Code on Social Security, 2020 (central law): in force since 21 November 2025. First time gig workers and platform workers are legally defined and recognized in Indian law. Aggregators (e.g. Uber, Swiggy, Zomato) must contribute 1-2% of annual turnover (capped at 5% of amounts paid to gig workers) into a Social Security Fund."
    },
    {
        "id": "css_benefits",
        "text": "The Code on Social Security 2020 covers life/disability cover, accident insurance, health and maternity benefits, old-age protection. Note that full scheme rollout is still being implemented as of this year — say 'schemes are being rolled out,' not that all benefits are already fully active and claimable today."
    },
    {
        "id": "karnataka_registration",
        "text": "Karnataka Platform Based Gig Workers (Social Security and Welfare) Act, 2025: in force since 30 May 2025, rules notified 19 November 2025. Workers get a unique registration ID, portable across platforms. Contracts and grievance processes must use simple, local language."
    },
    {
        "id": "karnataka_refusal_deduction",
        "text": "Under the Karnataka Platform Based Gig Workers Act, 2025, workers have the right to refuse a task without penalty. Aggregators must give 14 days' notice before changing contract terms. Payment deduction reasons must be disclosed to the worker."
    },
    {
        "id": "karnataka_grievance_exclusions",
        "text": "Under the Karnataka Platform Based Gig Workers Act, 2025, at least one human grievance contact point is required (not fully automated). IMPORTANT: this Act does NOT mandate a minimum guaranteed wage or a minimum per-km/per-trip rate, and does NOT guarantee compensation for waiting time — never claim it does."
    },
    {
        "id": "nch_helpline",
        "text": "National Consumer Helpline: 1915 or 1800-11-4000, also via WhatsApp (8800001915), the NCH web portal, or the NCH app. Operates in 17 languages. Staffed 8 AM-8 PM daily including holidays (web/WhatsApp accept complaints 24/7, processed during those hours). This is a CONSUMER helpline for disputes with a platform's service/goods — appropriate for consumer-side complaints."
    },
    {
        "id": "labor_grievance_escalation",
        "text": "For a wage or labor-specific grievance specifically (e.g. underpayment, unfair deactivation), direct the worker toward their state's Labour Department or, in Karnataka specifically, the Karnataka Platform Based Gig Workers Welfare Board (headquartered in Bengaluru) instead of 1915 — do not conflate consumer complaints with labor/wage grievances."
    }
]

# Simple tokenizer: lowercase, filter stopwords, apply basic stem rules
def tokenize(text):
    tokens = re.findall(r'\b\w+\b', text.lower())
    stems = []
    for t in tokens:
        if t in STOPWORDS:
            continue
        # Basic Porter-like stem suffixes for plurals and common suffixes
        if len(t) > 4:
            if t.endswith('s') and not t.endswith('ss'):
                t = t[:-1]
            if t.endswith('es') and not t.endswith('ees'):
                t = t[:-2]
            if t.endswith('ed'):
                t = t[:-2]
            if t.endswith('ing'):
                t = t[:-3]
        stems.append(t)
    return stems

# Build vocabulary and precompute IDF stats
vocab = set()
idf = {}
N = len(CHUNKS)

doc_counts = Counter()
for chunk in CHUNKS:
    tokens = set(tokenize(chunk["text"]))
    vocab.update(tokens)
    for tok in tokens:
        doc_counts[tok] += 1

for word, count in doc_counts.items():
    idf[word] = math.log((1 + N) / (1 + count)) + 1

# Convert text into a sparse TF-IDF vector
def get_tfidf_vector(text):
    tokens = tokenize(text)
    tf = Counter(tokens)
    vector = {}
    for word, count in tf.items():
        if word in idf:
            vector[word] = count * idf[word]
    return vector

# Cosine similarity between two sparse vectors
def cosine_similarity(v1, v2):
    dot_product = sum(v1.get(word, 0) * v2.get(word, 0) for word in v1)
    mag1 = math.sqrt(sum(val ** 2 for val in v1.values()))
    mag2 = math.sqrt(sum(val ** 2 for val in v2.values()))
    if mag1 == 0 or mag2 == 0:
        return 0.0
    return dot_product / (mag1 * mag2)

# Precomputed chunk vectors
chunk_vectors = [(chunk, get_tfidf_vector(chunk["text"])) for chunk in CHUNKS]

def retrieve_top_k(query_text, k=2, similarity_threshold=0.1):
    q_vec = get_tfidf_vector(query_text)
    scored_chunks = []
    for chunk, c_vec in chunk_vectors:
        sim = cosine_similarity(q_vec, c_vec)
        if sim >= similarity_threshold:
            scored_chunks.append((sim, chunk["text"]))
    # Sort descending by similarity
    scored_chunks.sort(key=lambda x: x[0], reverse=True)
    return [text for _, text in scored_chunks[:k]]
