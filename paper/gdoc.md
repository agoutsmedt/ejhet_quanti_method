# Introduction

In the last decade, the number of history of economics papers employing
quantitative methods has increased [see e.g.,
@goutsmedtQuantitative2023 special issue]. Several essays have adopted
a reflexive stance, examining the implications of using quantitative
methods in the history of economics [@cherrierQuantitative2018;
@edwardsQuantitative2018]. These contributions have aimed to provide
broad discussions on the use of such methods. However, given the
virtually unlimited variety of quantitative approaches potentially
relevant to historians of economics---and the wide array of research
questions they can address---these reflections often remain abstract and
offer little practical guidance. As a result, they tend to provide
useful broad overviews, but without clearly articulating what
quantification entails in practice, and how it can be both meaningful
and challenging to integrate into historical research.

Our contribution sits between a historical study that uses quantitative
methods to answer a specific question and a general methodological
discussion of those methods. From the collection of data to the
interpretation of results, we illustrate concretely how these methods
are useful and examine, in practice, the methodological choices they
entail. We present a step-by-step application of specific quantitative
methods to a broad topic: the history of rationality in the 20th
century.

We focus our discussion on unsupervised methods that have been
particularly influential in the history of economics. Unsupervised
methods are machine-learning techniques in which algorithms identify
patterns from unlabelled data, as opposed to supervised learning
methods---such as regressions---that learn patterns from labelled data
to make inferences. Their goal is not necessarily to provide a "measure"
[@grimmerText2022]---though they can be adapted to do so---but to
organise in categories large corpora and enable accelerated and "distant
reading" [@morettiDistant2013; @guldiDangerous2023]. They are well
suited to historical inquiry because their unsupervised nature reduces
the risk of presentism: rather than imposing present-day categories on
the past, unsupervised algorithms uncover patterns directly from the
data. When time is explicitly incorporated, they allow researchers to
map the discipline at different points of time, to identify the
emergence and decline of subjects and concepts, and to assess the
influence of specific economists.

Our article uses two types of data, texts and citations, that have been
particularly effective in recent quantitative studies, texts and
citations. The analysis of textual corpora offers a direct window into
the semantic content of debates, while citation data, on the other hand,
provides a lens through which to view intellectual interconnections and
structures of influence within the discipline. We show how a large
corpus of documents can be classified based on the information contained
in textual and citation data---what we call "textual clusters" and
"bibliometric communities."[^1]

Above all, our discussion aims to illustrate a core principle for
historical inquiry with such unsupervised quantitative methods. They
require continuous back-and-forth between aggregate quantitative
results, complementary indicators used for interpretation, and
preliminary knowledge and close reading of primary sources. These
methods function not only as a form of corroboration but also as
"discovery methods" [@grimmerText2022]: they facilitate the
exploration of large datasets to reveal historical patterns. They often
confirm, and sometimes complement, established findings. They can also
reveal pitfalls and blind spots in existing research.

The idea of "rationality" is an effective focus for a concrete
demonstration. First, many historians of economics engage with it in one
way or another, which makes the exercise relevant for a broad audience.
Second, because the concept is broad and pervasive in economics,
applying quantitative methods to a very large corpus is particularly
informative.[^2] We use a corpus of around X articles extending back to
1900 to show how these methods can handle long time horizons. Third, the
multiple meanings attached to "rationality" and its uses applied to
various subjects show how textual methods, coupled with bibliometrics,
can help capture this semantic plurality.

In what follows, we concentrate on what such a quantitative analysis
requires in practice. We highlight what kinds of questions and
challenges arise at each stage of the research process. This focus lets
us highlight (a) the crucial issue of selecting sources and building
data; (b) how even simple quantitative assessments can be informative;
(c) the challenges and subjective choices involved in building and
adapting tools; and (d) why interpreting results demands careful
attention to various indicators and close knowledge of both the corpus
and its historical context. By tracing, step by step, how we assemble
and analyze our corpus, we aim to provide a practical example and a
reflection on broader methodological issues faced by quantitative
historians of economics.

# **From sources to corpus**

## From sources to data

Discussions on quantitative methods often focus on the varieties of
existing methods. In practice, however, analysis and interpretation come
last. Most effort goes into collecting, cleaning, and structuring data,
much of which remains invisible in published work. Sources rarely arrive
as ready-to-use datasets; they must be transformed from somewhat raw
materials into usable corpora. In short, the quantitative historian must
be as much a data wrangler as a data analyst.

Bibliometric databases are a convenient way to access corpora of
economic texts: they record relatively well-structured data, gathering
key features of scientific output---such as authors, journals and
affiliations, *etc*.. Some of these databases, such as *Web of Science,
OpenAlex,* or *Scopus,* record citation data, which enables tracing
intellectual influence through diffusion patterns, and mapping scholarly
contributions over time.

Each database has its own strengths and weaknesses. While at a very
general level Web of Science, OpenAlex, or Scopus have similar coverage
[@martinGoogle2021; @culbertReference2025], some studies might suffer
from choosing a less appropriate database regarding the research
questions. For instance, Scopus has a lower coverage of the top 5
economics journals before the 1990s and while being openaccess, OpenAlex
has been less curated than the products of private publishers. Whatever
the provider, less successful or now-defunct journals are also more
likely to have incomplete or discontinuous digital coverage, impeding
their inclusion for historical analyses. Additionally, databases are
oriented toward English-speaking contributions; these databases may thus
be deficient for a research project targeting another or multiple
languages.[^3] Last but not least, although they provide useful metadata
and citation information, these databases generally lack full text,
which is subject to copyright and therefore cannot be obtained from a
single publisher.

Even when citations and full texts are available, the amount and quality
of information that can be reliably encoded remain limited. Citation
data are notoriously difficult to structure because both the notion of
what constitutes a reference and the conventions for recording it have
changed over time. As a result, an article may extensively cite a
document---such as a working paper or a report---that does not follow
standard bibliographic formats and thus never appears in citation
databases. Full texts face similar limitations: mathematical expressions
and empirical material, such as tables, are often poorly captured or
inconsistently encoded by providers. These shortcomings restrict what
can be studied by a quantitative analysis.

**A first important point is, therefore, that data availability shapes
what we are able to ask and so to answer.** The scarcity and structure
of available data affect every stage of inquiry, from the choice of
research questions to the interpretations of quantitative results. In
practice, research may be shaped as much by the scarcity of our data as
by researchers' own preferences. It is of course possible to build
handmade datasets from scratch, but, in the case of textual and citation
data, such tasks remain time-consuming beyond small-scale study. More
commonly, it is often necessary to combine information from existing
databases to fulfill a particular goal. For example, even for a
medium-scale study of the publications of the European Economic Review
[@goutsmedtIndependent2023]---few thousands documents---required to
combine three heterogenous databases: Econlit (for JEL codes
classification) Web of Science and Scopus (for missing coverage of Web
of Science). In their study of the French journal *La Revue Economique,*
@DelceyRevue2025 had to enrich the dataset provided by the journal with
missing full texts and authors' information from the digital libraries
Persée, Cairn, and IdRef.

For our study of rationality, the first step was to identify the best
sources. For citation data, the Web of Science provides the most
reliable and consistent coverage for our period and has been widely used
in the history of economics. As for full text, we relied on three
providers. First, JSTOR's full-text collection offers high-quality scans
of most leading economics journals. Second, we used Scopus to identify
peer-reviewed economics journals not included in JSTOR and collect a new
list of articles. We retrieved full texts first through the Elsevier
Full-Text API, when available. Finally, remaining full texts were
obtained through the ISTEX project, which provides access to a
substantial corpus of documents for researchers affiliated with French
universities.[^4]

The @fig-distribution shows the distribution of this corpus. It can be
already noted that our corpus disproportionately represents Anglo-Saxon
journals, which are also those most systematically digitized and
preserved. Not only do we tend to overlook other traditions of research,
but this also raises a serious issue of presentism: the fact that
retrospective data on these journals are easily accessible today does
not imply that they were equally central in earlier ones, nor that
articles were the dominant vehicle for the diffusion of ideas. Rather,
it reflects the fact that they had the resources and opportunities to
digitize and maintain comprehensive digital archives of their
publications.

Once access to full text is secured, another crucial step is to
transform them into a usable database. While Web of Science citations
are already delivered in a relatively structured form, full texts
require substantial processing. In most cases, data are not given but
result from a process that involves cleaning, categorizing, and
selectively removing or reformatting information from raw sources in
order to produce a dataset suitable for computational analysis. This
challenge is particularly true in the history of economics, where the
primary sources are the texts themselves---often unstructured and
interspersed with various layers of metadata, such as section headings,
footnotes, bibliographic references, or editorial annotations. This
requires making important choices well before the actual stage of
analysis.

Our first choice was to restrict the analysis to English-language
articles, since cross-language comparisons involve additional
challenges, which would go far beyond the scope of this article.[^5] We
also restrain our analysis to research articles and filter out book
reviews, comments, editorial reports or obituaries.[^6] While such
materials can illuminate how rationality was debated, they are not
primary sites for articulating new ideas within the discipline.
Moreover, textual data are by nature voluminous, and filtering improves
tractability for large-scale computation. At the document level, we
focused on the body text and removed (as far as possible) peripheral
elements such as acknowledgements, references, or appendices. We also
focus on natural-language text and remove other information that is
poorly OCR-processed and often unusable, such as mathematical formulas
and empirical tables.

**This data wrangling is not a tedious prelude to "real" historical
analysis**. Manipulating, cleaning, and structuring raw sources is a
fundamental and often generative stage of research. As
@lemercierQuantitative2019[62] reminds us, collecting and
categorizing sources is also "a moment to reflect on the sources and the
purpose of the research." Direct engagement with raw data can prompt the
reevaluation of initial hypotheses and the emergence of new questions.
In our case, preparing full‐text documents raises basic design choices
about inputs and, by extension, what counts as a relevant economic text.
Should we include book reviews, editorials, working papers, or
conference proceedings? How should we define an "economics
journal"---restrict it to core outlets or extend it to interdisciplinary
venues where economics appears regularly? Even within a single article,
boundaries are ambiguous: should abstracts, footnotes, appendices, or
acknowledgments be analyzed or excluded? Each decision may carry
historiographical implications. It shapes the corpus and, ultimately,
the history of rationality our methods can reveal. There is rarely a
single definitive and uncontestable choice, but rather a series of
trade-offs that should be made explicit and required to engage with some
of the material available.

To give a specific example, it is only after a first batch of
exploratory analysis that we notice that some important economics
journals were missing in JSTOR. If it was obvious from preliminary
results that the emergence of behavioral economics impacted how
economists discussed rationality, from our own expertise on the matter,
we observed that some journals like the *Journal of Economic Behavior &
Organization* or the *Journal of Behavioral Economics*---later to be the
*Journal of Socio-Economics*---were missing in places where they should
be predominant. This prompted us to further explore potential biases in
JSTOR and to augment our corpus with new full texts extracted from
Elsevier and the ISTEX project. Exploring raw sources is thus an
important step that requires to already engage with your material and
the existing literature.

The use of several databases also raised specific issues. Here, our goal
was to combine our textual data (from the three providers mentioned
above) with citation data from WoS. Achieving this required linking
documents across datasets, yet WoS---like many databases---does not
provide DOIs, which would otherwise serve as convenient unique
identifiers. It therefore fell to us to develop matching procedures to
determine whether an article retrieved from JSTOR or Scopus corresponded
to the same article indexed in WoS. However, matching based solely on
the title is unreliable. For example, the title *"Inflation and
Unemployment"* may refer either to James Tobin's AEA presidential
lecture or to Milton Friedman's Nobel lecture. Consequently, we had to
supplement title information with additional metadata, including the
journal name---which required standardizing journal titles across
databases---as well as the publication year, volume, issue, and page
range. Differences in journal coverage and in data storage practices
(particularly title formatting) mean that it is generally impossible to
achieve a complete match between databases. In our case, approximately
one-quarter of the full-text documents could not be matched to WoS
records, which prevents us, when relevant, from analyzing their citation
data.[^7]

## From data to corpus

In parallel with the transformation of sources into data, we also needed
to establish the boundaries of our corpus, a process that involves
selecting materials either *ex ante*, when choosing which sources to
include, or *ex post*, when filtering the collected data. In the context
of our project on the history of rationality in economics, this required
us first to determine what qualifies as "economics," and second to
identify which documents or parts of documents can be considered "texts"
about rationality.

The first challenge was thus to define the extent of our corpus a
priori, i.e. to delineate economics as an object of study. Some research
objects are relatively easier to delineate, and the transition from a
database to a well-defined corpus is therefore straightforward. For
example, writing the history of a particular journal
[@edwardsFifty2020; @DelceyFama2025] or of one or several individuals
[@trucDisciplinary2025] entails comparatively definitional or boundary
challenges. In contrast, most objects studied by historians lack clear
definitions or boundaries. While some large-scale studies focus on the
discipline as a whole [@claveauMacrodynamics2016;
@trucInterdisciplinarity2023; @ambrosinoWhat2018], such work still
requires an operational definition of what are documents in "economics."
This definitional issue becomes even more pronounced when the object of
study is a specific "field" (Cherrier, this issue) .

**Quantitative contributions force the researcher to settle on a narrow
but operational definition of the object under study.** Non-quantitative
historical methods, by contrast, tend to address large objects by
focusing on their "core" rather than their boundaries: historians of
economics typically reconstruct the history of materials that are
unambiguously part of the object under study, thus making a narrow
definition often unnecessary. Quantitative approaches, however, require
a well-defined corpus and consequently oblige researchers to impose
simple, clear-cut boundaries on complex and ambivalent categories such
as "economics". Defining the relevant historical materials therefore
requires the adoption of specific conventions to approximate the object
under study [@DesrosieresPolitique_1993]. Therefore, defining a corpus
constitutes a quantification convention---one that must always be
assessed instrumentally, not as an absolute definition but as an
operational hypothesis serving a specific research question.

Many proxies have been used in the history and philosophy of economics
to define disciplines and sub-disciplines. For instance,
[@goutsmedtIndependent2023] used the JEL codes to select macroeconomic
documents in a corpus of well-established economics journals, while
[@trucForty2022] and [@jullienHistory2024] relied respectively on
citations data and institutional affiliations to identify the boundaries
of behavioral economics.[^8] To choose a particular proxy, it is
important to understand how it relates to the object under study. Both
JEL codes and journal classifications---like JSTOR or Scopus
classifications---can structure a corpus in ways that reflect their own
histories, and researchers must therefore consider how these proxies
shape the boundaries of their material. For example, while the JEL codes
for neuroeconomics emerged around the same time as the first
publications in the field, the JEL codes for behavioral economics
appeared more than two decades after the earliest contributions
[@trucNeuroeconomics2023]. Understanding the historical development of
such proxies is thus essential for interpreting the nature of the corpus
they produce. More generally, a thorough knowledge of the history of the
object being studied is crucial for evaluating the adequacy and
representativeness of the resulting corpus.

In our case, we first define economic documents by building the corpus
from peer-review journals. This convention has both advantages and
limitations. On the one hand, this approach is unambiguous, as it relies
on agreeing upon a predefined list of journals, rather than, for
instance, determining at the document level which individual articles
qualify as economics. Moreover, journals constitute one of the main
legitimate institutional markers of a discipline, alongside training
programs and professional associations. On the other hand, focusing on
journals means excluding other publication outlets, such as books or
working papers.[^9] In addition, it struggles to capture
interdisciplinarity, whether in the form of interdisciplinary journals
or of economists publishing in other disciplinary journals. Finally,
this strategy requires the use of arbitrary criteria to decide which
journals to include and which to exclude---particularly for journals at
the margins of "economics", either because of their interdisciplinary
orientation or because of uncertainty regarding their peer-review
standards or academic practices.[^10] We eventually settled on a
carefully curated list of 329 journals identified as economics journals
in JSTOR and Scopus, but excluding journals that are not entirely
academic, insufficiently focused on economics, or only founded within
the last twenty years.[^11] We were able to retrieve 337,086 articles
published in these journals from 1900 to 2009.

The second challenge was to restrain our corpus to documents engaging
with the issue of rationality. One of the most straightforward proxies
are keywords [@trucNeuroeconomics2023]. Based on a predefined list of
target terms (often called a "dictionary"), this approach restricts a
corpus to documents that mention these terms with at least a given
frequency. In addition to its relative simplicity, it works well for
specific and unambiguous terms, like "stagflation" and "Great Inflation"
[@goutsmedtStagflation2021] or "Agent-Based Models"
[@bacciniDoes2025]. But this approach may display several limitations
when it is not the case. Indeed, it focuses on spotting occurrences of a
term rather than a general idea. Just think about the various ways
rationality could be discussed in the history of economics: beyond the
term of "rationality" itself, economists employ various expressions that
refer to close ideas such as maximising profits or expected utility, the
*homo oeconomicus*, or the transitivity or completeness of preferences.

Going beyond simply searching for occurrences of "rationality" and
"rational," we could have constructed an extensive dictionary of terms
associated with the concept of rationality. This task requires
substantial knowledge of the history of economics and of debates
surrounding rationality, and thus presupposes that researchers possess
adequate historical and conceptual background. Despite this, it remains
difficult to prevent the dictionary-building process from introducing
biases---for instance, by omitting concepts that are historically
relevant but salient only during specific periods (such as "hedonism"),
or by creating a disproportionate dictionary, with many terms related,
for instance, to decision theory but few pertaining to macroeconomics or
public economics. Consequently, this approach also constrains the
potential for discovery: by setting the boundaries of the dictionary in
advance, researchers may unintentionally exclude terms or themes of
which they were unaware, and thus remain unaware of them throughout the
analysis.

To overcome this issue, we use a Large Language Model (LLM) to identify
documents---and even specific sentences within documents---that deal
with rationality in our corpus of economic articles.[^12] LLMs are
algorithms trained on extremely large collections of text to learn
patterns in language. In simple terms, they learn to predict missing
words in a sentence or to determine whether two sentences follow each
other. Through this training, the model develops billions of internal
parameters that capture regularities in vocabulary, grammar, and
meaning. When we input text into such a model, it translates sentences
into vectors that summarize their context and meaning. This enables us
to compare sentences not by the exact words they use but by their
underlying ideas. For example, the same term---such as "model"---may
carry different meanings depending on the surrounding context (*fashion
model* vs *scientific model)* and a LLM can detect these variations. By
converting words and sentences into vectors that reflect their semantic
usage, LLMs make it possible to treat ideas and conceptual shifts as
measurable objects, thereby opening new possibilities for the
quantitative study of economic thought.

We rely on Sentence-BERT [@reimersSentenceBERT2019], an LLM designed
specifically to produce sentence embeddings, that is, numerical vectors
that represent the meaning of a sentence. The model assigns one vector
to each sentence, which allows for straightforward semantic comparison:
sentences that express similar ideas end up with vectors that are
mathematically close to each other. Using Sentence-BERT, we vectorized
more than 61 million sentences published between 1900 and 2009 from our
database. Starting from sentences including "rationality" and
"rational", we then searched for the sentences most similar to these
anchor sentences. Thus, if sentence A explicitly uses the word
"rationality," and its vector is close to that of sentence B---which
never mentions the term---sentence B likely discusses a related idea.

Our approach does not simply consist of finding sentences that are close
to the words "rationality" and "rational" over a 110-year period,
though. Because our project is historical, it is crucial to consider how
LLMs themselves handle historical language. LLMs are trained on billions
of texts, but the overwhelming majority of these texts are recent.[^13]
As a result, they tend to offer a "presentist," numerical view of
language. For example, current models struggle to reproduce writing
styles from earlier periods and cannot reliably infer the publication
date of a text [@underwoodCan2025]. Sentence-BERT is subject to the
same limitations, and the sentence embeddings it produces inevitably
reflect this bias. Besides, as illustrated by @fig-distribution, our
corpus is exponential according to years and most sentences come from
recent articles. Taken together, these effects make it very likely that
the sentences the model identifies as closest to "rationality" will
predominantly come from recent articles. To limit this presentist
effect, we adapted the way we compare sentences over time. Instead of
comparing a sentence from, say, 1910 directly to *all* sentences in our
corpus that contain the words "rationality" or "rational," we
constructed a "representative vector" that is a moving average vector
with a five-year window. Concretely, for the year 1910, we averaged the
vectors of all sentences containing "rationality" or "rational" from
1905 to 1915. This produces a period-specific reference point that
reflects how these terms were used *at that particular moment in time*.
A sentence from 1910 is therefore judged similar not to the general, and
likely modern-day meaning of rationality, but to the way the concept was
expressed during its own historical period. This helps ensure that our
analysis is sensitive to historical changes in language. Since each
document is a set of sentences, we can also identify the documents---and
the authors---that discuss rationality most intensively or frequently.
@tbl-illustrative_sentences and @tbl-illustrative_documents illustrate
respectively the closest sentence and documents (represented by the mean
of its vectors) from our representative vectors in 1910.

# **Exploring the corpus** 

# Simple exploration

Once the corpus has been assembled---which, as we have explained, is far
from a "simple" task---the next challenge is to identify how the concept
of rationality is used within these texts and how its uses evolve over
time.

Quantitative approaches come in many forms and levels of complexity.
Indeed, quantification does not need to be sophisticated to be useful.
Simple indicators may not always provide definitive answers to research
questions, but they can play an important exploratory role: helping
researchers refine their questions, identify anomalies, or detect
unexpected patterns.

For textual data, one of the most straightforward indicators is term
frequency, that is counting how often particular words or expressions
appear. This metric has been used repeatedly in the literature,
especially to track the emergence or decline of fields within economics.
In well-delimited domains, term frequency can serve as a reliable proxy
for intellectual dynamics. For instance, @trucNeuroeconomics2023 shows
that counting occurrences of highly specific neuroeconomics terms---such
as "striatum" or "prefrontal"---closely approximates more advanced
quantitative measures, and thus provides a simple but meaningful signal
of activity in the field.

For our study or rationality, frequencies of words "rational" and
"rationality" already offer important insights. @fig-relative-frequency
shows the relative frequency (with respect to the total number of words
published each year) of "rational" and "rationality." The figure reveals
a clear surge in the 1980s and 1990s, suggesting a rise in the
mobilization and discussion surrounding relates to the rise of "rational
expectations" in macroeconomics and the emergence of behavioral
economics with the publication of [@kahnemanProspect1979]. While we
can't rationality. In 1981, the word represented XXXX% of all words,
XXXX more times than in 1970. Obviously, we can't easily infer from such
simple metrics what it means, but it strongly know what drives this
rise, it certainly signals an important moment for the evolution of
rationality in economics in terms of intensity, thus prompting for more
focused investigation. Another important result from this simple graph
is that we only find one large anomalous surge associated with a period
where rational choice theory begins to be contested. We could have
expected another period of intense controversy during the 1920s followed
by a "normalization" of rationality. Instead, we find a slow rise of the
occurrence of "rational" words between the 1900s and 1960s signalling a
slow and progressive adoption rather than a sudden shift.

To probe this simply dynamic further, we can also investigate how the
term is used in specific context with simple metrics. Our aim is to move
beyond keyword retrieval and recover the different meanings and
intellectual settings in which "rationality" and "rational" are invoked.
A direct way to begin is co-occurrence analysis: examining the words
that most often appear immediately before or after our keywords. Such
co-occurrences indicate the conceptual frames and debates in which the
term is embedded.

@fig-co-occurence reports, by decade, the five words most frequently
adjacent to "rational" and "rationality," showing how associations shift
over time. Before the 1940s, the picture was heterogeneous, with links
to philosophy, psychology, and general notions of reasoning (e.g.,
"rational conduct", "rational organization"). From the 1940s onward, the
rise of choice theory places rationality at the center of economic
modeling as a device for describing and formalizing behavior. This is
mostly visible with the rise of multiple common bi-grams (i.e.,
combination of two words) that remain stable from the 1930s through the
1980s such as "economic rationality", "rational choice", "rational
behavior". By the 1970s---and especially the 1980s---the framework was
both extended and contested. First, the most common bi-gram by far
becomes "rational expectations" signalling the emergence of a new
predominant concept extending rationality.. During the 1980s "rational
expectations" appeared XXXX more times than the other most common
bi-grams. Second, while we generally associate the rise of "bounded
rationality" with Herbert Simon in the 1950s, we can observe that the
concept only became prevalent during the 1990s with the bi-gram becoming
the third most common one in the 2000s. The rise of "bounded
rationality" is also accompanied by a relative decreasing importance of
"rational expectations" itself. While it remains the most common bi-gram
even in the 2010s, it decreased from XXXX times the second most common
occurrence in the 1980s to XXXX in the 2010s.

**Beyond textual analysis, another important source of information is
documents metadata** (e.g., authors, journals, institutions, citations).
We focus here on citations to study how articles on rationality cite and
are cited. The evolution of an idea often depends as much on how it is
circulated and appropriated by readers as on how it was formulated by
its authors. A large literature on Citation Theory has developed around
how to interpret citations as a scientific practice and its measures
[@TahamtanCore1979]. A wide range of factors influence citation
practices. From a genuine desire to acknowledge intellectual debt to
more strategic considerations aimed at persuading readers or satisfying
peer reviewers, but at the very least citations indicates a relationship
that traces between ideas' lineage and their diffusion even if its basis
is not only intellectual.

One major structural issue for quantitative analysts using metadata is
temporal: systematic citation practices are relatively recent, so
citations present poor quality and reliability before the 1960s. In
contrast to textual analysis, thus, bibliometric analysis in economics
is largely confined to the postwar period. A second constraint is data
scarcity and quality: extracting and standardizing references at scale
is complex and imperfect. For this reason we rely on Web of Science for
structured citation data, despite its proprietary cost and access
limits. We then augment our JSTOR full-text corpus with Web of Science
citations and with citation and abstract data for key journals missing
from JSTOR.

Simply counting citations can be used to proxy engagement and better
understand the impact of a particular author or publication. There are
clear reasons to incorporate citation studies into historical research.
Beyond tracking diffusion, highly cited papers are more visible and
attract more engagement (Matthew effect). Recent work also suggests that
citations shape reading behavior and perceived quality: highly cited
papers are more likely to be read closely and to be seen as substantial
intellectual influences [@teplitskiyHow2022].

Historians routinely discuss scientific influence, and recognition using
proxies such as major grants, prizes, and honors. For example,
@sent_behavioral_2004 narrative of the transition from the dominance of
rational choice, through the limited success of "old" behavioral
economics (e.g., Simon, George Katona), to the rise of "new" behavioral
economics is organized around such milestones. In this sense, citations
serve as a complementary proxy alongside traditional markers. For
example, while both Simon and Kahneman received the Nobel, they had very
different impact on the trajectory of economics in terms of scale,
something visible in part by citations. In a large
qualitative--quantitative study of the Nobel Prize, @offerNobel2016
distinguished several profiles: laureates who peak at the prize then
decline, "innovators with staying power," "still rising" winners honored
before their citation peak, and late winners recognized long after their
peak. Relating institutional rewards to citation and publication
patterns clarifies how recognition interacts with diffusion, reception,
and appropriation.

@fig-rationality-paper-citations plots citation patterns for four
seminal references on bounded rationality across all economics journals
and the top five. The selection is partly arbitrary but standard in the
literature: @simonBehavioral1955 and
@allaisComportementHommeRationnel1953 are early critiques of
neoclassical rational choice with both empirical and normative
implications, while @akerlofMarket1970 and @kahnemanProspect1979 are
early "new" behavioral landmarks that mark the emergence and growth of
what is simply known as "behavioral economics" for economists.

The influence of "new" behavioral economics overwhelms that of "old"
behavioral economics, in both the top five and the full set of economics
publications indexed in Web of Science. Whereas @simonBehavioral1955
and @allaisComportementHommeRationnel1953 are never cited by more than
0.20% of all economics-article, @kahnemanProspect1979 reached at least
1% by the late 2010s and continues to rise. The contrast is both in
scale of influence and speed of acceptance: citations to the two "new"
behavioral papers grow rapidly and steadily right after publication,
whereas Simon and Allais peak around the time of their Nobels or only
much later in the 2010s wit the emergence of "new" behavioral economics.
As argued by @offerNobel2016, many laureates receive a "Nobel premium,"
a modest post-prize citation bump. Simon and Allais fit this pattern,
but for Kahneman and Tversky the effect is extreme: after the Nobel,
their declining trend reverses and climbs throughout the sample
[@offerNobel2016].

Whether we talk about metadata or textual analysis, such simple tools
are perfect because they can be learned quickly by any historians and
mobilized in a few days to complement an otherwise qualitative
perspective. However, it is also possible to deploy more advanced (and
often custom) tools that address specific questions that the researchers
has in mind. With this type of tools, the role of quantitative analysis
in a given study can shift from complementary to being the leading
method of a study (although not necessarily).

## More advanced exploration

Citation counts are a blunt tool and can be extended in several ways.
One can examine *who* cites a work---by discipline, journal, or
subfield---and assess the *qualities* of citations, i.e., distinguishing
positive from negative citations or functional roles in the text
(litterature review, methodology...) [@budiUnderstanding2023]. Another
way to use citations is to transform citation data into relational data.
A prominent example commonly used in the history of economics is
bibliographic coupling. Coupling maps relationship between articles by
using the similarity of reference lists: articles are nodes, and the
more references two article share, the closer they appear in a
two-dimensional layout. The premise is that shared references proxies
intellectual proximity. These maps help delineate the frontiers of
disciplines, fields or sub-specialities and expose their internal
organization, including hierarchical and/or core-periphery structures.
Using cluster detection algorithm, we identify and groups sets of
documents that share a substantial fraction of references and thus have
a similar intellectual background. **Our bibliometric clusters thus
group documents that are likely to engage with rationality in similar
ways based on citations patterns.**

Similarly with textual analysis, word counting and textual co-occurrence
analysis offers a first view of how talk about rationality changes, but
it is limited to the immediate lexical neighborhood of a word and thus
to proximity in vocabulary, not meaning. Two sentences may share no
terms---"rational behavior" and "profit maximization"---yet point to
closely related conceptions of agency and choice. To move from this
semantic approach to a conceptual approach, we turn to recent advances
in natural language processing: large language models (LLMs). These
models encode context and meaning, allowing us to compare sentences that
are semantically similar even when their vocabularies diverge, and to
see how the same word takes on different meanings across contexts.
**This approach allows for sentence-clustering to identify shared
conceptions of rationality across various economics texts and to track
large shifts in the way the concept is used over time.**

At the fundamental level, both bibliographic clustering and sentence
clustering do a similar operation: **they bring some form of internal
order to a large corpus**. Using both methods we are able to identify
subgroups within our corpus across multiple dimensions: different
sub-fields of economics (e.g., behavioral economics, macroeconomics),
different conceptions of rationality (e.g., bounded rationality,
rational expectations) or even more heurestically different methods
(e.g., experimental, econometrics).

Both methods can be used independently depending on the question at
stake, but in our case, they are interdependent and complementary.
First, running bibliographic coupling begins with delimiting a relevant
corpus: which articles count as being "about rationality"? Keyword
searches are brittle, since papers on revealed preference or prospect
theory may not use the words "rational" or "rationality." Using our LLM
sentence embeddings from JSTOR we are able to determine to which degree
an article engages with rationality in its content independently for the
occurrence of the word. For our purpose, we retain the top 10% articles
that engaged the most intensively with rationality and formed a corpus
suitable for bibliometric coupling (see Appendix XXXX). Second, and as a
direct followup to that, both method allows for a variety of
quality-cross check. Running bibliometric coupling on a corpus created
using our sentence embedding allows us to navigate our copus in a
structured manner and make sure that it work as intended. In addition,
the systematic comparison of sources and methods is a fundamental
principle of historical analysis, needed to triangulate information.
Comparing the results from bibliometric and textual clusterizations
allows us to identify large trend that are true when looking both at
textual patterns and citations patterns. Moreover, because we used two
different databases for our two methods (JSTOR for textual analysis and
Web of Science for citation analysis), this add another dimensions for
triangulations of our results.

## Interpreting "Results"

**Like with simple tools, advanced quantitative methods do not yield
objective, ready-made outputs.** In our case, they produce statistical
groupings---bibliometric communities and textual clusters---that require
qualitative interpretation. This is a classic strategy to reduce a large
and complex set of texts to a manageable number of simple categories.
But these clusters are constructed on the basis of statistical
commonalities, whose actual conceptual meaning can only be characterized
through qualitative assessment. More importantly, a good qualitative
knowledge of the corpus and of intellectual debates at stake are
indispensable to make sense of raw results. **Thus, whether in the
collection of data or their analysis, quantitative methods require a
constant back-and-forth with qualitative reasoning.** This is especially
important because our methods are "unsupervised." With no prior labels
to guide classification, human interpretation is central to assessing
validity and usefulness.

An example of a results from this analysis stems from "bounded
rationality" related clusters. The cluster 40 from the textual analysis
is a cluster that exists between 1950 and 2019. We find:

-   Wide range of concepts related to bounded rationality: "bounded
    rationality", "collective rationality", "procedural rationality".

-   Herbert Simon as the most recurring author in number of sentence
    which capture the strong relationship to "old" behavioral economics
    of the cluster, but also Robert Sugden as a "new" behavioral
    economists, or Gary Becker as an example of a proponent of rational
    choice theory who heavily engaged with irrationality

-   A mixed of top mainstream journal (The American Economic Review,
    Econometrica) with more heterodox or specialized journals (Cambridge
    Journal of Economics, Journal of Economic Issues)

-   Example of sentences:

    -   Althought has long been agreed that traditional economic theory
        "assumes" rational behavior, at one time there was considerable
        disagreement over the meaning of the word "rational." (Becker,
        1962)

    -   [R]ationality in real life must involve something simpler than
        maximization of utility or profit. (Simon, 1959)

    -   The various questions that have been raised about the
        rationality assumption appear to have legitimized and encouraged
        the development of economic theories that model departures from
        economic rationality in specific contexts. (Kahneman, 2003)

While it grows rapidly in size over time, this textual cluster more
generally capture the general controversies in economics surrounding
rationality as framed as an "rationality vs irrationality vs bounded
rationality" problem in economics. This is well captured by the mixed of
authors but also of core dominant journals with more frontiers and
heterodox journals.

At the opposite, the bibliographic analysis reveal multiple clusters
that capture sub-fields of economics structured by bounded rationality.
For example clusters (1) "XXXRISK" and (2) "XXXXSOCIAL" are
characterized as follow:

-   Wide range of concepts related heuristics, biases and the
    experimental method: (1) "experimental", "risk-aversion", "endowment
    effect" and (2) "reciprocity", "fairness", "ultimatum",
    "cooperation", "trust".

-   The clusters are structured by the work of new behavioral economists
    like Kahneman, Tversky, Richard Thaler, Colin Camrer, Matthew Rabin
    or Ernst Fehr.

-   Top mainstream journals (The American Economic Review, Econometrica)
    mixed with specialized journals (Journal Of Risk And Uncertainty,
    Journal Of Economic Behavior & Organization, Games And Economic
    Behavior, Experimental Economics)

This time the cluster is not structured by a large debate about bounded
rationality, but by the more specific approach of "new" behavioral
economists understood as the heuristic and biases research program. Even
more precisely, the two clusters make a distinction within "new"
behavioral economics between economists working on pro-social behavior
and those working on risk and uncertainty. Contrary to textual analysis,
we find no real cluster centered around the work of Simon besides a few
exceptions like another cluster around operations research. While the
textual clusters capture a particular way to discuss rationality in
economics which bridge "old" and "new" behavioral economics by this
shared interest, the bibliometric cluster analysis reveal the emergence
of a sub-fields in the profession with specialized journals and a small
set of tightly connected authors that are very different from Simon's
original contribution.

At this point, the clusters only brings some internal order to our
corpus and highly different structural patterns in the way rationality
has shaped economics whether via its discourse or by the emergence of
specific communities. From this type of quantitative results, it is
possible to extract historical narrative and develop historical claims
by bringing together more traditional approaches in history of economics
thought, the historical litterature with our quantitative results.

# **Discussion**

How can these complex quantitative methods and their careful
interpretation contribute to our understanding of the history of
rationality? How can they help enrich, complete, and refine our
understanding of the various and evolving meanings of rationality in
economics? This paper does not propose an alternative history of the
concept, nor a comprehensive account of its evolution. Its aim is to
show, concretely, the benefits, limits, and uses of quantitative methods
in the history of economics.

We highlight selected findings that confirm and strengthen strands of
the existing literature, broaden its scope, and open paths for further
research. We combine multiple indicators with qualitative analysis,
reading articles the models pointed out. Our goal is to show how we
navigate results and triangulate indicators to produce clear insights
and coherent narratives.

## Retrieving general patterns from the history of rationality

An obvious way we can use our results is by looking at long term general
patterns, something that can be difficult without using quantitative
methods. This has two advantages. First, we can write long-spanning
histories by focusing on the macro-level shifts in economics as a whole
rather than reconstructing it from patchwork of different contributions.
Second, even when focusing on sub-fields or specific issues relating to
rationality, we are able to recontextualize narrow narratives in a
larger picture.

An example of a first big picture shift concerns the evolving
relationship between economics and psychology at the beginning of the
19th century. A common narrative is that psychology was "in" during the
neoclassical revolution, then "out" with the ordinal and revealed
preference revolution," then "back in" with the behavioral and
experimental economics [@giocoliModeling2003; @handsEconomics2010].
These large movement can be well captured by synthetic metrics like
citations between disciplines [@trucNeuroeconomics2023] but it can be
quite difficult to connect to the historical literature like
@giocoliModeling2003 who analyze big figures in economics such as
Vilfredo Pareto, Irving Fisher, Lionel Robbins, and Paul Samuelson, to
reconstructs the long-standing debate over the relation between
economics and psychology. With our textual analysis we are able to
identify these different episodes by large shift in how rationality is
used and discussed, but also by whom they are discussed.

The movement of psychology "in" economics is characterized by the
prevalence of hedonistic psychology in economics. This debate about the
role of hedonism in explaining behavior appears clearly in Cluster 2
(@fig-llm-alluvial), which extends from 1900 to the 1940s. This cluster
is characterized by terms that completely disappeared from contemporary
economic vocabulary: "satisfaction", "pleasure", "instinct", "human
nature", "pain". The cluster brings together advocates of hedonistic
foundations and their critics, notably institutionalists who questioned
psychological grounding. Wesley C. @mitchellRole1916 [160]
illustrates this opposition in one of the closest sentences to our
representative vector: "to find the basis of economic rationality in the
development of a social institution directs our attention away from that
dark subjective realm, where so many economists have groped, to an
objective realm, where behavior can be studied in the light of the
common day".

As the hedonistic cluster disappear in the 1940s, it is replaced by
multiple clusters that capture the shifting away from psychology toward
perfect rationality in economics. This is captured by cluster 31 in the
1940s, notably Friedman and Savage [@friedmanUtility1948], and
especially after 1950 in cluster 46. This clusters reunite the debates
about demand theory, the use of cardinal utility, and the possibility of
interpersonal comparisons. Chicago economists such as Friedman and
Savage [@friedmanExpectedUtility1952], Stigler
[@stiglerDevelopment1950], and later Becker [@beckerIrrational1962]
are prominent. In parallel, Nicholas Georgescu-Roegen offered a sharp
critique of "utility" and its measurability
[@georgescu-roegenChoice1954]. The notion of perfect rationality also
structured many other related clusters such as the ones about price
theory (cluster 28, 1940 to 1989) or profit maximization (cluster 30,
1940 to 1969) where rationality becomes a more standardized concept
embedded in particular economic theories.

From the 1980s onward, challenges to the standard rationality approach
embodied by expected utility theory emerged in several textual clusters
(e.g., clusters 83 and 93) and persisted until the end of our period. A
distinct behavioral economics cluster (106) appeared in the 2000s. This
trend is confirmed by the bibliometric analysis that shows a first
community labeled "Behavioral Economics and Choice Theory" in
1977--1984, followed by many communities after 2000 that form a dense
network around the issue of how to model rationality
(@fig-biblio-alluvial), something we will explore further in the
following sections.[^14]

Another big picture shift is the relationship between macroeconomics and
microeconomics. While the history of the relationship between economics
and psychology even as told by @giocoliModeling2003,
@handsEconomics2010, or @heukelomBehavioral2014 mostly focus on
microeconomics, our approach embedded this individual rationality
history into a larger scope. For example, a structural distinction in
our quantitative analysis is between individual-focused clusters and
more macro or general economics clusters.

For example, as psychology is driven out economics and the discussions
surrounding rationality become less about hedonistic concepts (pleasure,
instinct), and more about economic concepts (profit, consumption...), we
find more economics-focused clusters. The 1940s and 1950s reveal two
textual clusters centered on debates over economic freedom and free
enterprise versus economic planning. These clusters include roundtables
and special issues on planning, such as a discussion sparked by Oskar
Lange's 1949 article [see @perrouxPractice1949], with contributions
by François Perroux, Jan Tinbergen, Evsey Domar, and Michał Kalecki.
They also include debates on "the proper spheres of individual freedom
and collective control in the 'good' economy" [@taylorEconomics1948],
in a collection that included, among others, Henry Simons. Across both
clusters, Frank Knight appears as a recurrent reference.[^15] Somewhat
linked to this is the textual cluster 53, which from the 1950s on
discussed social choice and welfare, with rationality framed as a guide
for decision makers.[^16]

For the most recent period, we find the emergence then domination of
"rational expectations" in the way rationality is discussed in
economics. In both bibliometric and textual analyses, from the 1970s
rational expectations became central and occupied substantial
discussion, appearing across multiple textual clusters and bibliometric
communities (@fig-llm-alluvial; @fig-biblio-alluvial). More generally,
during the 1970s, most clusters are about macroeconomics issues or
economics-oriented issues. In the 1970-1977 coupling network, the five
biggest clusters are about (1) rational expectations and macroeconomics,
(2) finance, (3) public goods and externalities, (4) public goods ; (5)
disequilibrium and Keynesian economics. While these clusters use
rationality in different ways and with different approaches, we find no
clusters dedicated to rationality issue at the individual level. This
situation change slowly during the 1980s. In the 1980-1987 network, we
find the "Game Theory and Information" (12% of the network) about
subgame perfect equilibrium and incomplete information (Reinhard Selten,
George Akerlof, John Harsanyi), and the "Behavioral Decision Theory"
clusters (2% of the network) capturing the beginning of behavioral
economics as promoted by Kahneman and Tversky.

Taken together, these individual-rationality clusters that did not
exists in the 1970s now represent 12% of the network. This share rose to
around 29% of the network in the 1990s and around 40% of the networks in
the 2000s. While existing history of rationality often focus on the
microeconomics side or the macroeconomics side, we are able here to
measure a large shift in where rationality is discussed. During the
1970s, as psychological approaches were marginalized, rationality
remained primarily embedded in sub-fields concerned with markets and
macroeconomic issues. The rise of behavioral economics and new
approaches in game theory fundamentally changed this dynamic, leading to
a specialized investigations of individual rationality that now
dominate. This transformation represents not just a change in research
topics, but a fundamental reframing of how economics approaches the
concept of rationality itself from an assumption embedded in aggregate
models to an object of direct investigation at the individual level.

These general patterns matches mostly known patterns in the history of
economics but with the advantage of situating them in a larger context
and weight their respective importance and relationship to each others.
However, it is also possible to highlight a more surprising results that
is less discussed in the historical litterature.

Beyond such long-spanning histories, it is also to focus on specific
issues to confront more explicitly existing historical narrative and
cross-check our quantitative results with more qualitative
investigations. In the following sections we focus on two issues in the
historical literature with the "rational expectations revolution" and
the "birth of behavioral economics".

## A rational expectations revolution ?

One focused read of our results centers on "rational expectations." The
concept has an early history: developed by @muthRational1961 for price
movements in agriculture; popularized when Carnegie colleagues---Robert
E. Lucas, Edward C. Prescott, and Thomas J. Sargent---applied it to
macroeconomics [@lucasExpectations1972; @sargentRational1973]. It
became central in the early 1970s and quickly controversial for monetary
and fiscal policy [see e.g., @sargentwallace1975]. By the late 1970s
it circulated in policy and the press and was often described as a
"rational expectations revolution" [@duarteRise2025].

Our methods help account for the rapid diffusion beyond controversial
policy debates during the stagflation era. First, the results show no
significant trace of rational expectations in the 1960s in either
bibliometric or textual outputs.[^17] From the 1970s it has taken a
central place in the literature on rationality.

The controversial character of rational expectations appears first in
the text analysis. Two clusters on rational expectations emerged in the
1970s (textual clusters 67 and 72). The first gathers articles that
debate the hypothesis itself, including many critiques of its
theoretical and empirical relevance in the 1970s--1980s. Others examine
the implications of adopting the hypothesis across domains. The second
focuses on models that use rational expectations rather than the
hypothesis per se.[^18] Here, alongside promotion of such
models---Sargent is a major contributor---there are early critiques
targeting both the rational-expectations assumption and additional
auxiliary assumptions. A clear example is Ray Fair's complaint about
"one class of macroeconomic models that have recently been developed"
which rely on "(1) the assumption that expectations are rational, given
the available information; (2) the assumption that information is
imperfect regarding the current state of the economy; and (3) the
postulation of an aggregate supply equation in which aggregate supply is
a function of exogenous terms plus the difference between the actual and
expected price level" [@fairCriticism1978, p. 411].[^19] Diffusion is
also visible in clusters that predate the use of rational expectations
but incorporate it from the 1980s onward, notably cluster 76 on monetary
economics and cluster 28 on price theory.[^20]

Our bibliometric analysis complements the text analysis. By tracking
references and using overlapping windows, it detects the emergence of
new communities and the split of others with fine temporal resolution.
The main rational‐expectations community, "Rational Expectations and
Business Cycles", first appeared in 1966--1973. It focuses less on the
hypothesis itself and more on its macroeconomic policy implications. The
controversy centers on modelling the inflation--unemployment trade-off
and the implied (in-)effectiveness of monetary policy. This aligns with
the early divide between "old" and (future) "new" Keynesians
[@goutsmedtReacting2019].

The controversial status of rational expectations in the 1970s--1980s
likely helps explain the prominence of this community in our results.
These controversies are well documented [@hooverNew1988;
@goutsmedtReacting2019]. At the same time, our evidence suggests
diffusion by application across domains. The bibliometric analysis
indicates two broad pathways. First, communities initially outside the
"Rational Expectations and Business Cycles" community began to
incorporate the assumption. Second, new communities gradually branched
off from the core community: articles that first co-located with the
main group increasingly coalesced into autonomous clusters.

Focusing on the first pathway, one community engaged with rational
expectations slightly earlier than the "Rational Expectations and
Business Cycles". This community addressed topics in trade, demand, and
investment within a general‐equilibrium framework. @muthRational1961
belongs to this community and remains a key reference, even though the
rational‐expectations hypothesis is not central. In 1971--1978, the
label shifts to "Investment and Economic Growth," where Lucas's early
work on investment is influential, albeit without using rational
expectations. Several important references in this window do employ the
assumption, including @cyertRational1974 and @townsendMarket1978. In
1975--1982, the community transformed into a new community, "Investment
and Uncertainty," now featuring @kydlandRules1977, @kydlandTime1982,
and @lucasAsset1978.[^21] Thus, beyond the well-known debates on
business cycles and inflation, parallel communities---only partly
focused on macroeconomic issues---were active in the early 1970s.

After the mid-1970s, several independent communities began to adopt
rational expectations. A first trajectory appears in 1976--1983: two
finance-oriented communities ("Asset Pricing and Consumption" and
"cl_319") partially merged into "Rational Expectations and Market
Information." At its core was imperfect information, with
@rothschildEquilibrium1976 as a key node. Another central contribution
was @grossmanImpossibility1980, which drew on Lucas's
imperfect-information framework [@lucasExpectations1972] and combined
rational expectations with noisy signals to question market efficiency
[see @delceyEfficient2023]. A second community emerged in 1979--1986
with "Game Theory and Information," where rational expectations became
more prominent. Here @kydlandRules1977 and @barroPositive1983 on time
inconsistency sit alongside @krepsSequential1982 on sequential
equilibria and @seltenReexamination1975 on equilibrium refinements. In
the early 1980s this community split, yielding "Monetary Policy and
Inflation," which leverages game-theoretic models to deal with
credibility and reputation in policy design.

A second diffusion process involves the emergence of new communities
organized around rational expectations that gradually separate from the
initial core. In the early 1970s, an international macroeconomics
community branched off from "Rational Expectations and Business Cycles."
Although it addressed a range of international macroeconomic topics, the
determination of exchange rate dynamics---and the role of the
rational-expectations hypothesis in that determination---quickly became
central, notably with Dornbusch's overshooting model
[@dornbuschExpectations1976]. From 1974--1981, another community grew
out of the core---"Inflation, Expectations and Interest Rates"---which
concentrated on the term structure and the use of interest rates to
forecast inflation. This community became a meeting ground for
macroeconomics and finance, where rational expectations and efficient
markets were closely linked [@delceyEfficient2023].

This issue of the diffusion of rational expectations merits a dedicated
study. Here, the goal is to illustrate the diversity of trajectories and
the fine-grained mapping our analyses produce, enabling productive
interaction between quantitative evidence and qualitative
interpretation.

By the early 1980s, roughly half of the network consisted of communities
engaging, to varying degrees, with rational expectations. At the same
time, a behavioral economics community had emerged, though it still
formed a small share of the network, a situation that changed after the
1990s.

## Simon's reception and the birth of behavioural economics

A second focus reading of our study concerns the birth of behavioral
economics. The term \"behavioral economics\" has a complex history, with
George Katona often credited as an early adopter [@giladEconomic1984;
@hosseiniGeorge2011]. @sent_behavioral_2004 made an historical
distinction between "old" and "new" behavioral economics to separates
the "old" heterogenous attempts by Katona, Simon and others to reform
mainstream economics from the "new" more homogenous heuristic and biases
research program of Kahneman and Tversky. Sent argues that \"new\"
behavioral economics succeeded precisely because it worked within the
existing paradigm rather than challenging it fundamentally.
Additionally, it emerged in the 1980s when economic theory faced
multiple epistemological challenges, creating an opportune moment for
alternative approaches. While our method cannot pinpoint the exact
epistemological reasons for this shift, we can trace the reception and
influence of both approaches to understand how and when they diverged.

Simon\'s concept of \"bounded rationality\" stands as one of the most
influential critiques of standard rationality in economics in the sense
that it framed a lot of the debates surrounding rationality. His
presence dominated 1950s discussions, with his seminal articles and
Nobel lecture [@simonRational1979] appearing across numerous research
areas from social choice theory to the theory of the firm and price
setting.

Our textual analysis reveals Simon\'s conceptual centrality. Textual
cluster 40, spanning roughly seventy years from 1950 onward, captures
general discussions on rationality in economics. While early debates
(1950s) focused on game theory and expected-utility theory
[@schellingAbandonment1959; @ellsbergTheory1956;
@marschakRational1950; @chernoffRational1954], by the 1970s \"bounded
rationality\" became the cluster\'s most prevalent expression. By the
1990s, discussions of \"boundedly rational agents,\" \"unbounded
rationality,\" and \"procedural rationality\" clearly positioned
Simon\'s concepts as central to economic thought signaling a late but
significant integration.[^22] This is corroborated by citation analysis
as citations to Simon (1955) only rised very slowly in economics after
its publications with peak citations happening in the post 2000s
(@fig-rationality-paper-citations).

However, this conceptual influence did not translate into stable
research communities. Bibliometrically, we find only small, unstable
clusters formed around Simon\'s work. From 1960--1967, his ideas
appeared in operations research circles (cl_5) and organizational theory
critiques of profit maximization. Simon his more generally associated
with other researcher critical perfect rationality like
@winterSatisficing1971, which applies satisficing to firm behavior, and
@cyertCompetition1969. A related strand is @leibensteinAllocative1966
on "X-efficiency," which challenges economics' focus on allocative
efficiency. Together, Simon, Winter, Cyert (with George), and
Leibenstein form a diverse critique of how rationality---especially
through profit maximization---is employed in economics, from an
organizational theory perspective. After 1969--1976, this stream landed
in a smaller, short-lived community (cl_175). References to Simon and
critiques of profit maximization then remain scattered, moving through
several small communities (cl_182, cl_251, cl_300, cl_328). While
Simon\'s influence in economics was enduring, it remains marginal.

In the 1977--1984 period, Simon\'s work was absorbed into a large
\"Behavioral Economics and Choice Theory\" cluster alongside Kahneman\'s
prospect theory. A similar phenomena can be observed in the textual
analysis as the textual cluster 40 commented earlier. The cluster
becomes increasingly populated by "new" behavioral economists (Matthew
Rabin, Daniel Kahneman or Robert Sugden) and now includes critical
comparison of "new" behavioral economics with other approaches such as
the one formulated by Nathan Berg and Berg Gigerenzer [@bergAs-if2010]
who criticize the tameness of "new" behavioral economcis models.

The crystallization of a distinct \"Behavioral Decision Theory\" around
Kahneman and Tversky\'s contributions signal the beginning of an
explosive growth of \"new\" behavioral economics. The cluster spins off
several autonomous communities capturing the emergence of sub-fields
within behavioral economics: pro-social behavior (cl_x), intertemporal
decision-making (cl_x), behavioral game theory (cl_x), and behavioral
finance (cl_x). By the 2000s, behavioral economics had become the
dominant venue for research on rationality, with five behavioral
economics clusters representing approximately 40% of the entire network.

The contrast with Simon is striking. While \"bounded\" and
\"procedural\" rationality remain regularly invoked concepts, no later
research community clearly carries Simon\'s heritage as a bibliometric
anchor. The scale and speed of acceptance differed dramatically between
the two approaches. By 1980, @kahnemanProspect1979 was already more
cited than @simonBehavioral1955 had been at that time
(@fig-rationality-paper-citations). By 1985, prospect theory had
surpassed the lifetime citation peak that Simon\'s work ever achieved in
economics. (@fig-rationality-paper-citations). By the 2000s, most
microeconomics publications about rationality are related to behavioral
economics, and more generally, most publications about rationality are
connected to the research program.

A first surprising results from our quantitative study is the stark
contrasting reception of Kahneman and Simon in terms of temporality. For
historian Floris Heukelom [@heukelomSense2012;
@heukelomBehavioral2014], a pivotal moment in the history of
behavioral economics is the explicit creation of research program within
the Sloan and Russell Sage Foundations between 1984 and 1992 that most
notably led to the pairing of Kahneman and Thaler that changed the
trajectory of behavioral economics. However, our quantitative analysis
suggests that even in the early 1980s it was clear that something
particular was happening in terms of reception with the work of Kahneman
and Tversky. Despite @kahnemanProspect1979 being the only economics
publication of duo until 1985 and long before the Sloan-Sage Foundation
research program (1984--1992) that formalized behavioral economics,
prospect theory became very cited rapidly
(@fig-rationality-paper-citations). As early as the 1977--1984
bibliometirc network, we find a cluster structured by the work of
Kahneman and Tversky suggesting that not only their article his cited,
but it rapidly structured a new strand of research in a way that never
happened with Simon's work in economics.

This is particularly remarkable given the external similarities between
the two cases. Both Kahneman and Simon published in top economic
journals and received Nobel Prizes. While Simon's Nobel only increase
his influence in economics marginally, Kahneman's Nobel reversed a
downward citation trend in the 2000s to an upward trend cimenting his
contribution as a structural pillar of a larger wide spanning research
program.

A second surprising result is that citations to @simonBehavioral1955
have never been higher than since the ascent of the new behavioral
economics. @earlPrinciples2022 is critical of how much "old" behavioral
economics seems to have been forgotten by "new" behavioral economists:

-   "Neither Kahneman nor Thaler have sought to promote earlier
    behavioral economics alongside more recent work. Instead, they give
    the impression that behavioral economics started around 1979--1980
    with the publication of Kahneman and Tversky's (1979) article on
    prospect theory and that theory's use by Thaler (1980). All in all,
    this is a very curious state of affairs: a cynic might suggest that
    it looks rather as if the earlier work has been airbrushed from the
    history of economic thought by the strategic redefinition of what
    constitutes behavioral economics. A more charitable and reflexive
    view would see the situation as resulting from insufficient
    familiarity with the earlier literature [\...]"
    (@earlPrinciples2022, p.2)

The rising citations to older work from Simon or Allais in our example
show that while it is possible that most "new" behavioral economics
rarely acknowledge the contributions of "old" behavioral economists, the
scale of the rise of "new" behavioral economics still led to more
attention paid to "old" behavioral economists than ever before in
economics. This resurgence admits at least three interpretations. A more
favorable reading is that the "new" program helped revive abandoned
research directions and moved toward reconciliation with earlier strands
(something promoted by @sentRationality2008 or more recently by
@earlPrinciples2022). A more unfavorable view sees intellectual
appropriation, in which classic references are reframed to fit the new
agenda, renewing interest but with a biased and presentist lens
[@monginAllais2019]. A third more critical interpretation is that the
citation increase reflects a growing backlash against the "new" program
from the standpoint of "old" behavioral economics. Preliminary evidence
supports the second interpretation. This is suggested by the sparse and
unstructured citations patterns to "old" behavioral economics and the
fact that discussions of rationality are increasingly framed by "new"
behavioral and experimental concepts. While a definitive conclusion is
beyond the scope of this paper, our study provides a roadmap for future
quantitative and qualitative research needed to further the
understanding of the relationship between "old" and "new" behavioral
economics.

Our quantitative studies delineates the specific chronology and
magnitude of the different attempts at stirring a behavioral shift in
economics. However, as made clear by @fig-rationality-paper-citations,
it is not just a linear story of a shift from one program to the other.
citations to @simonBehavioral1955 have never been higher than since the
ascent of the new behavioral economics. This resurgence admits at least
three interpretations. A more favorable reading is that the "new"
program helped revive abandoned research directions and moved toward
reconciliation with earlier strands (something promoted by
@sentRationality2008 or more recently by @earlPrinciples2022). A more
unfavorable view sees intellectual appropriation, in which classic
references are reframed to fit the new agenda, renewing interest but
with a biased and presentist lens [@monginAllais2019]. A third more
critical interpretation is that the citation increase reflects a growing
backlash against the "new" program from the standpoint of "old"
behavioral economics. Preliminary evidence supports the second
interpretation. This is suggested by the sparse and unstructured
citations patterns to "old" behavioral economics and the fact that
discussions of rationality are increasingly framed by "new" behavioral
and experimental concepts. While a definitive conclusion is beyond the
scope of this paper, our study provides a roadmap for future
quantitative and qualitative research needed to further the
understanding of the relationship between "old" and "new" behavioral
economics.

# **Conclusion**

# 

[^1]: The bibliometric communities, identified through network analysis,
    could also be called clusters. But we opted for "communities" in
    order to distinguish them from the "textual clusters".

[^2]: To be clear, we don't think that quantitative methods are only
    helpful for very large corpora. However, it is where their surplus
    value may appear as the more obvious.

[^3]: One of the main challenges for a quantitative history of economics
    is to move beyond reliance on proprietary digital libraries and to
    actively develop open, historically inclusive corpora. This includes
    incorporating materials produced in non-Anglophone countries and
    expanding the range of textual formats considered---such as books,
    book reviews, working papers, and conference proceedings.

[^4]: For more detailed information on the collection of data, see the
    appendix.

[^5]: Indeed, most textual methods are designed to identify
    commonalities within texts that share a specific linguistic
    structure. Hence, the same topic discussed by two documents in two
    different languages will likely not be identified as related because
    linguistic differences mask underlying semantic similarity**.**

[^6]: This filtering draws on JSTOR's and Scopus' own classifications,
    supplemented by some additional filtering from ourselves. Despite
    these safeguards, a perfectly clean restriction to research articles
    was not feasible, and some residual non-article items likely remain.

[^7]: See the appendix for more information on the matching process.

[^8]: X study fragmentation of economics through the "blue ribbon" of
    economics journals... (OeConomia special issue)

[^9]: Adding these other outlets would pose additional challenges. For
    both working papers and, above all, books, no large-scale databases
    provide comprehensive full texts or complete reference lists. In
    addition, working papers raise the problem of potential double
    counting, as they may eventually be published in economic journals.

[^10]: Pottier et al. were confronted to this point when studying...
    [More general references about the explosion of the number of
    journals and the questions it raised in studying specific field...]

[^11]: We did not filter journals by language a priori. Indeed, many
    national non-anglo-saxon journals also published in English at some
    more or less frequent occasions. It was thus easier to filter by
    language a posteriori and at the document level, once articles were
    collected.

[^12]: Our goal here is not to provide the reader with extensive details
    on what these models are and how we use them (see the appendix for
    additional details and references), but rather to provide general
    intuitions about the use of the LLMs, to understand the building of
    our corpus.

[^13]: Moreover, the texts used to train these models are not primarily
    academic articles in economics. This means that there may be
    important gaps between the general language patterns the model has
    learned and the specific vocabulary, concepts, and writing practices
    of our "domain" [see e.g. @zhangEconBERT2025].

[^14]: See for instance the communities "Behavioral Economics and
    Experiments", "Ambiguity and Uncertainty", "Intertemporal Choice and
    Control" or "State Preference Valuation".

[^15]: See also textual cluster 31 on planning issues.

[^16]: Kenneth Arrow, Herbert Simon or James Buchanan are central in
    these debates.

[^17]: This highlights a key caveat. Because these methods foreground
    statistically "significant" patterns and indicators' prevalence,
    they are not always well suited to tracing and interpreting the
    origins of a concept or theory with the care that close historical
    study and archival research provide.

[^18]: The second textual cluster is less centered on rational
    expectations than the first. It aggregates model-focused
    debates---some on rational behavior in general, others on
    demand---within which rational-expectations models remain prominent.

[^19]: The mix of defense and opposition continues into the
    2000s--2010s: we see discussions of DSGE models , alongside macro
    models with bounded rationality or learning and arguments for
    behavioral macroeconomics and rational inattention.

[^20]: Other clusters linked to rational expectations cover inflation
    expectations and the term structure in the 1970s (cluster 78),
    forecasting (81), wages and unemployment (82), finance (87),
    information (89), econometric issues (92), and a more theoretical
    intersection of rational expectations and game theory from the 1980s
    (88).

[^21]: These articles received a good number of citations from the paper
    of this community, but they appear as "connector" in the sense that
    they were highly connected to nodes in other communities.

[^22]: Simon himself became one of the most prevalent words of the
    cluster.
