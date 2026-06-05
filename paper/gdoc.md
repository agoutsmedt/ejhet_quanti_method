# Introduction

In the last decade, the number of history of economics articles
employing quantitative methods has increased [see e.g.,
@goutsmedtQuantitative2023]. Several essays have adopted a reflexive
stance, examining the implications of using quantitative methods in the
history of economics [@cherrierQuantitative2018;
@edwardsQuantitative2018]. These contributions provided broad
discussions on the use of such methods. However, given the virtually
unlimited variety of quantitative approaches potentially relevant to
historians of economics---and the wide array of research questions they
can address---these reflections often remain at an abstract level and
offer little practical guidance. As a result, they tend to provide
useful broad overviews, but without clearly articulating what
quantification entails in practice, and how quantitative methods can be
both meaningful and challenging to integrate into research specific to
the history and philosophy of economics.

Our contribution sits between a historical study that uses quantitative
methods to answer a specific question and a general methodological
discussion of those methods. From the collection of data to the
interpretation of results, we illustrate concretely how these methods
are useful and examine, in practice, the methodological choices they
entail. We present a step-by-step application of specific quantitative
methods to a broad topic: the history of rationality in the twentieth
century---using this case to illuminate, in practice, what choices
quantitative analysis involves.[^1]

We focus our discussion on unsupervised methods. Unsupervised methods
are machine-learning techniques in which algorithms identify patterns
from unlabelled data, as opposed to supervised learning methods that
learn patterns from labelled data, based on pre-defined categories, to
make inferences. The goal of unsupervised methods is not necessarily to
provide a "measure" [@grimmerText2022]---though they can be adapted to
do so---but to organise in categories large corpora and enable
accelerated and "distant reading" [@morettiDistant2013;
@guldiDangerous2023]. They are well suited to historical inquiry
because their unsupervised nature reduces the risk of presentism: rather
than imposing present-day categories on the past, unsupervised
algorithms uncover patterns directly from the data. When time is
explicitly incorporated, researchers can map the discipline at different
points in time, to identify the emergence and decline of subjects and
concepts, and to assess the influence of specific economists or ideas.

Our article draws on two types of data, texts and citations. The
analysis of textual corpora offers a direct window into the semantic
content of economic contributions, while citation data provides a means
of tracing intellectual connections and channels of influence within the
discipline. We show how a large corpus of documents can be classified
based on the information contained in textual and citation data---what
we call "*semantic clusters*" and "*bibliometric communities*."[^2]
Combining both allows us to illustrate concretely the use of two popular
sets of data for the history of economics. This combination is also
justified by what we regard as a crucial principle of quantitative
analysis in the history of economics and other disciplines: the
triangulation of different sources of data and the validation of results
through the comparison of findings obtained from distinct methods.

Above all, our discussion aims to illustrate a core principle for
historical inquiry with such unsupervised quantitative methods. They
require continuous back-and-forth between aggregate quantitative
results, complementary indicators used for interpretation, as well as
preliminary knowledge and close reading of primary and secondary
sources. These methods function not only as a form of corroboration but
also as "discovery methods" [@grimmerText2022]: they facilitate the
exploration of large datasets to reveal historical patterns. They often
confirm, and sometimes complement, established findings. They can also
reveal pitfalls and blind spots in existing research.

The concept of "rationality" is an effective focus for this concrete
demonstration. First, many historians of economics engage with it in one
way or another, which makes the exercise relevant for a broad audience.
Second, because the concept is broad and pervasive in economics,
applying quantitative methods to a very large corpus is particularly
informative.[^3] We use a corpus of 259,165 articles in economics
between 1900 and 2009 to show how these methods can handle long time
horizons. Third, the multiple meanings attached to "rationality" and its
uses applied to various subjects show how textual methods, coupled with
bibliometrics, can help capture this semantic plurality.

In what follows, we concentrate on what such a quantitative analysis
requires in practice. We highlight what kinds of questions and
challenges arise at each stage of the research process. This focus lets
us highlight *(a)* the crucial issue of selecting sources and building
data; *(b)* how even simple quantitative assessments can be informative;
*(c)* the challenges and subjective choices involved in building and
adapting tools; and *(d)* why interpreting results demands careful
attention to various indicators and close knowledge of both the corpus
and its historical context. By tracing, step by step, how we assemble
and analyze our corpus, we aim to provide a practical example and a
reflection on broader methodological issues faced by historians of
economics in quantitative inquiries. The analysis of the results relies
on the use of an interactive application that we have built for this
article.[^4]

# **From sources to corpus**

## From sources to data {#sec-sources_data}

Discussions on quantitative methods often focus on the varieties of
existing methods. In practice, however, implementing a method and
interpreting its results come last. A great deal of effort goes into
collecting, cleaning, and structuring data, much of which remains
invisible in published work. Sources rarely arrive as ready-to-use
datasets; they must be transformed from somewhat raw materials into
usable corpora. In short, the quantitative historian is often a data
wrangler as much as a data analyst.

Bibliometric databases are a convenient way to access corpora of
economic texts: they record relatively well-structured data, gathering
key features of scientific output---authors, journals, affiliations,
*etc*. Some of these databases, such as those provided by *Web of
Science, OpenAlex,* or *Scopus,* record citation data, which enables
tracing intellectual influence through references and mapping scholarly
contributions over time.

Regarding data availability, each database has its own strengths and
weaknesses. While at a very general level Web of Science, OpenAlex, or
Scopus have similar coverage [@martin-martinGoogleScholarMicrosoft2021;
@culbertReference2025], some studies might suffer from choosing a less
appropriate database regarding the research questions. For instance,
Scopus has a lower coverage of the "top five" economics journals before
the 1990s and, while being open-access, OpenAlex has been less curated
than the products of for-profit publishers. Whatever the provider, less
central or now-defunct journals are more likely to have incomplete or
discontinuous digital coverage, impeding their inclusion for historical
analyses. Additionally, as these databases are oriented toward
English-speaking contributions, they may be inadequate for a research
project targeting other languages.[^5] More generally, citation
practices have only standardised progressively in the postwar period.
Consequently, citation data are most of the time relatively poor before
the 1960s. Last, although they provide useful metadata and citation
information, these databases generally lack full text, which is subject
to copyright and therefore. A large and representative corpus of
economics articles cannot be obtained from a single publisher.

Even when citations and full texts are available, the quality of
information that can be reliably encoded remains limited. Citation data
are difficult to structure, because both the very notion of what
constitutes a reference and the conventions governing its recording have
changed over time---for instance, from references embedded in footnotes
to the development of standardized bibliographies and the author--date
system [@graftonFootnote1999]. Full texts face similar limitations:
mathematical expressions and empirical materials, such as those included
in tables, are often poorly captured by providers and difficult to
encode properly. These shortcomings restrict what can be studied by
quantitative tools.

In short, the availability and quality of data determine what can be
asked and so answered. The scarcity and structure of data affect every
stage of inquiry, from the choice of research questions to the
interpretations of quantitative results. Scholars are not condemned to
rely on existing databases and may build handmade textual and citation
datasets from scratch. However, such tasks remain time-consuming beyond
small-scale study. More commonly, it is often necessary to combine
information from different databases to fulfill a specific goal. For
example, a medium-scale study of the publications of the European
Economic Review [@goutsmedtIndependent2023]---a few thousands
documents---required combining three heterogeneous databases: Econlit
(for JEL codes classification), Web of Science, and Scopus (due to
incomplete coverage of the EER in Web of Science).

For our study of rationality, the first step was to identify the best
sources. For citation data, the Web of Science (WoS) provides a reliable
and consistent coverage for our period
[@culbertReference2025;@martin-martinGoogleScholarMicrosoft2021] and
has been widely used in the history of economics
[@claveauMacrodynamics2016]. As for full text, we relied on three
providers. First, JSTOR's full-text collection offers relatively
good-quality scans of most leading economics journals
[@jstorText2025]. Second, we used Scopus to identify peer-reviewed
economics journals not included in JSTOR and to compile a complementary
list of articles; for these, we retrieved full texts from Elsevier, when
available.[^6] Third, remaining full texts were obtained from the ISTEX
project [@istexInfrastructure2025], which provides access to a
substantial corpus of documents for researchers affiliated with French
universities.[^7] We obtain a raw corpus of 812,191 documents, written
in different languages and of heterogeneous types (research articles,
book reviews, etc.), which will subsequently be filtered.

The @fig-distribution shows the distribution of this raw corpus across
the years and languages. Our corpus disproportionately represents
Anglo-Saxon journals, which happen to be the most systematically
digitized and preserved. This skew is problematic on two fronts. First,
it risks marginalizing research traditions poorly represented in
English-language articles. Second, it introduces a form of presentism:
the retrospective accessibility of these journals' data today should not
be conflated with their historical centrality, nor should it imply that
journal articles constituted the dominant medium for the circulation of
scholarly ideas. Their prominence within the raw corpus reflects less
their past influence than their greater capacity, through resources and
institutional support, to maintain comprehensive digital archives.
Conversely, the materials missing "are unlikely to be missing at random"
[@stoltzMapping2024, 11].[^8]

Once access to full text is secured, another crucial step is to
transform them into a usable database. While WoS citations are already
delivered in a relatively structured form, full texts require
substantial processing. In most cases, data are not given but result
from a process that involves cleaning, categorizing, and selectively
removing or reformatting information from raw sources in order to
produce a dataset suitable for computational analysis. This challenge is
particularly true in the history of science and ideas, and more
specifically in the history of economics, where the primary sources
often are the texts themselves. These texts contain layers of noisy
content, such as section headings, footnotes, or bibliographic
references.

This data wrangling is not a tedious prelude to "real" historical
analysis. Manipulating, cleaning, and structuring raw sources is a
fundamental and often generative stage of research. As
@lemercierQuantitative2019[62] reminds us, collecting and
categorizing sources is also "a moment to reflect on the sources and the
purpose of the research." Direct engagement with raw data can prompt the
reevaluation of initial hypotheses and the emergence of new questions.
In our case, preparing full‐text documents raises choices about what
counts as a relevant economic text. Should we include book reviews,
working papers, or conference proceedings? How should we define an
"economics journal"---restrict it to core outlets or extend it to
interdisciplinary venues where economics appears regularly? Even within
a single article, boundaries are ambiguous: should abstracts, footnotes,
or appendices be analyzed or excluded? Each decision may carry
historiographical implications. It shapes the corpus and, ultimately,
the history of rationality our methods can reveal. There are rarely
definitive and uncontestable choices, but rather a series of trade-offs
that should be made explicit and requires engaging with some of the
material available at hand.[^9]

In light of this article's purpose, we operated a series of choices in
extracting textual data from the full-text materials provided by JSTOR,
Elsevier, and ISTEX. Our first choice was to restrict the analysis to
English-language articles, since cross-language comparisons involve
additional challenges, which would go far beyond the scope of this
article.[^10] We also restrict our analysis to research articles and
filter out book reviews, comments, editorial reports or obituaries.
While such materials can illuminate how rationality was debated, they
are not primary sites for articulating new ideas within the discipline.
Moreover, textual data are by nature voluminous, and filtering improves
tractability for large-scale computation. At the document level, we
focused on the body text and removed (as far as possible) peripheral
elements such as acknowledgements, references, or appendices. We also
focus on natural-language text and remove other information that is
poorly OCR-processed and often unusable, such as mathematical formulas
and data tables.

To illustrate how corpus delineation and cleaning constitute an
iterative process, it was only after an initial round of exploratory
analysis that we noticed the absence of important economics journals for
our purpose in JSTOR. While preliminary results clearly indicated that
the rise of behavioral economics had impacted how economists discussed
rationality, our domain expertise suggested that certain journals like
the *Journal of Economic Behavior & Organization* or the *Journal of
Behavioral Economics*---later to be the *Journal of Socio-Economics* and
then the *Journal of Behavioral and Experimental Economics*---were
missing precisely where they should have figured prominently. This
prompted us to further explore potential biases in JSTOR and to augment
our corpus with new full texts extracted from Elsevier and the ISTEX
project. Exploring raw sources is thus an important step that requires
already engaging with both collected materials and the existing
literature.

The use of several databases also raised specific issues. Here, our goal
was to combine our textual data (from the three providers mentioned
above) with citation data from WoS. Achieving this required linking
documents across datasets, yet WoS does not provide DOIs, which would
otherwise serve as convenient unique identifiers. It therefore fell to
us to develop matching procedures to determine whether an article
retrieved from JSTOR or Scopus corresponded to the same article indexed
in WoS. However, matching based solely on the title is unreliable. For
example, the title *"Inflation and Unemployment"* may refer either to
James Tobin's [-@tobinInflation1972] AEA presidential lecture or to
Milton Friedman's [-@friedman1977] Nobel lecture. Consequently, we had
to supplement title information with additional metadata, including the
journal name---which required standardizing journal titles across
databases---as well as the publication year, volume, issue, and page
range. Differences in journal coverage and in data storage practices
(particularly title formatting) mean that it is generally impossible to
achieve a complete match between databases. In our case, approximately
25% of the full-text documents after 1960 could not be matched to WoS
records, which prevents us from analyzing their citation data.[^11]

## From data to corpus {#sec-data_corpus}

In parallel with the transformation of sources into data, we also needed
to establish the boundaries of our corpus. This selection can be made
*ex ante*, when choosing which sources to include, or *ex post*, when
filtering the collected data. In the context of our project on the
history of rationality in economics, we had to determine what qualifies
as "economics," and second to identify which documents or parts of
documents can be considered "texts" about rationality.

The first challenge was thus to delineate economics as an object of
study. Some research objects are relatively easier to delineate, and the
transition from a database to a well-defined corpus is therefore
straightforward. For example, writing the history of a particular
journal [@charlesRevue2025;@edwardsFifty2020], or of one or several
individuals [@andradaUnderstanding2017; @trucDisciplinary2025]
entails comparatively fewer definitional or boundary challenges. While
some large-scale studies focus on the discipline as a whole
[@ambrosinoWhat2018;@bacciniExploring2025;@claveauMacrodynamics2016],
such work still requires an operational definition of what are documents
in "economics." This definitional issue becomes even more pronounced
when the object of study is a specific "field" or "research specialty"
[@lyutovMachine2021;@morrisMapping2008].

Non-quantitative historical approaches often address large objects by
focusing on clearly identifiable cases or canonical contributions,
allowing the scope of inquiry to remain flexible and progressively
defined. For instance, a historical inquiry on rational expectations may
take @muthRational1961 as a starting point, or focus on the reactions
to Lucas' [-@lucasExpectations1972] model. Quantitative approaches, by
contrast, require the explicit delineation of a corpus from the outset,
which entails making operational choices about inclusion criteria. How
should a corpus on rational expectations be constructed? Which journals
should be included? Should one restrict attention to articles explicitly
mentioning "rational expectations," or also consider related
formulations such as "model-consistent expectations"? Defining the
relevant historical materials therefore involves adopting explicit
conventions to approximate the object under study
[@desrosieresPolitics2011]. The act of delimiting a corpus is a
convention and such an act must be assessed instrumentally, not as a
definitive delineation, but as an operational hypothesis tailored to a
specific research question or even an act of "drawing impossible
boundaries" [@lietzDrawing2020; @zittBibliometric2019].

Many "proxies" have been used in the history and philosophy of economics
to define disciplines and sub-disciplines. For instance,
[@fontanaFragmentation2023] restrict their economics corpus to the
allegedly most influential economics journals, the "Blue Ribbon Eight";
[@goutsmedtIndependent2023] used the JEL codes to select macroeconomic
documents; while [@trucForty2022] and [@jullienHistory2024] relied
respectively on citations data and institutional affiliations to
identify the boundaries of behavioral economics. However, such
approximations have implications for the object under study. Both JEL
codes and journal classifications---like JSTOR or Scopus
classifications---structure a corpus in ways that reflect their own
histories, and researchers must consider how these classifications shape
the boundaries of their material. For example, while the JEL codes for
neuroeconomics emerged around the same time as the first publications in
the field, the JEL codes for behavioral economics appeared more than two
decades after the earliest contributions [@trucNeuroeconomics2023]. A
thorough knowledge of the history of the object studied is thus crucial
for evaluating the adequacy and representativeness of the resulting
corpus.

In our case, we define *economics* documents by building the corpus from
a list of *peer-reviewed* journals. This convention has both advantages
and limitations. On the one hand, it provides a clear and reproducible
criterion, relying on a predetermined set of journals, rather than
requiring case-by-case decisions about whether individual documents
qualify as "economics". Journals also constitute a central institutional
marker of a discipline, alongside training programs and professional
associations. On the other hand, this choice excludes other publication
outlets, such as books and working papers.[^12] In addition, it only
partially captures interdisciplinarity, missing interdisciplinary
journals or economists publishing in other disciplinary journals.
Finally, this choice also entails boundary decisions regarding which
journals to include, particularly for those at the margins of
"economics", due to their ambiguous editorial standards. We eventually
settled on a carefully curated list of 329 journals identified as
economics journals in JSTOR and Scopus, but excluding journals that are
not entirely academic, insufficiently focused on economics, or only
founded within the last twenty years.[^13] Filtering the raw corpus to
retain only English-language research articles from these journals, we
obtain 259,165 articles published between 1900 and 2009. These articles
constitute what we have called our *meta-corpus*.

The second challenge was to restrict our corpus to documents engaging
with the issue of rationality. One of the most straightforward proxies
is keywords [@trucNeuroeconomics2023]. Based on a predefined list of
target terms (called a "dictionary"), this approach restricts a corpus
to documents that mention these terms with at least a given frequency.
In addition to its relative simplicity, it works well for specific and
unambiguous terms, like "stagflation" [@goutsmedtStagflation2021] or
"Agent-Based Models" [@bacciniDoes2025]. But this approach may exhibit
several limitations in other cases. Indeed, it focuses on identifying
instances of a term rather than the concept as a whole. Just think about
the various ways rationality could be discussed in the history of
economics: beyond the term "rationality", economists employ various
expressions that refer to close ideas such as "maximising profits",
"expected utility", the "*homo oeconomicus*,*"* or the "transitivity"
and "completeness of preferences."

Going beyond searching for occurrences of "rationality" and "rational,"
we could have constructed an extensive dictionary of terms associated
with the concept of rationality. It remains difficult to prevent the
dictionary-building process from introducing biases---for instance, by
omitting concepts that are historically relevant but salient only during
specific periods (such as "hedonism"), or by creating a disproportionate
dictionary, with many terms related, for instance, to decision theory
but few pertaining to macroeconomics or public economics. Consequently,
using a list of words constrains the potential for discovery: by setting
the boundaries of the dictionary in advance, researchers may
unintentionally exclude terms or themes of which they were unaware, and
thus remain unaware of them throughout the analysis
[@huistraPhrasing2016; @underwoodDistant2019, chapter 1].

To overcome this issue, we use a Large Language Model (LLM) to identify
documents---and in particular specific sentences within documents---that
deal with rationality in our meta-corpus of economic articles.[^14] LLMs
are trained on extremely large collections of text to learn patterns in
language. The type of models we use, i.e. bidirectional encoder models
such as BERT, learns to predict missing words in a sentence or to
determine whether two sentences follow each other. Through this
training, the model learns billions of internal parameters that capture
regularities in vocabulary, grammar, and meaning. Such a model
represents texts as vectors---called embeddings---that capture their
context and meaning. The relative position of each vector in this space
reflects semantic proximity: standard distance metrics---such as cosine
similarity---can then be used to compare, rank, or hierarchically
cluster sentences by meaning.[^15] This enables us to compare sentences
not by the exact words they use but by their underlying meaning. For
example, the same term---such as "model"---may carry different meanings
depending on the surrounding context (*fashion model* vs *scientific
model)* and a LLM can detect these variations. By converting words and
sentences into vectors that reflect their semantic usage, LLMs make it
possible to treat ideas and conceptual shifts as measurable objects,
thereby opening new possibilities for the quantitative study of economic
thought.

We rely on Sentence-BERT [@reimersSentenceBERT2019], a LLM designed
specifically to produce sentence embeddings, that is, numerical vectors
that represent the meaning of a sentence. The model is fine-tuned for
semantic comparison between sentences: sentences that express similar
ideas end up with vectors that are mathematically close to each other.
Using Sentence-BERT, we vectorized more than 61 million sentences
published between 1900 and 2009 from our meta-corpus. Starting from a
set of *sentences A* including "rationality" and "rational", we can
compute their centroid, that is the vector obtained by averaging the
embeddings of *A*. We call such a centroid vector a "representative
vector", as it encapsulates the semantic meaning of rational and
rationality in our meta-corpus. Then, we could retrieve a set of
*sentences B* that are the most similar to this centroid. Thus, from a
set of *sentences A* explicitly mentioning the words "rationality" and
"rational," we retrieve a set of *sentences B*---which may never mention
the terms but likely discuss a related idea such as profit-maximization
[see @ashIdeas2026 for a similar use].

Despite their remarkable potential, LLMs have important limitations for
historical analysis. Computing a single representative vector over 110
years raises serious historical issues: these models are trained on vast
amounts of text, the majority of which are recent, and therefore reflect
a presentist bias in their representation of language.[^16] For example,
current models struggle to reproduce earlier writing styles and cannot
reliably infer the publication date of a text [@underwoodCan2025].
Sentence-BERT is subject to the same limitations, and the sentence
embeddings it produces inevitably inherit this bias. Besides, as
illustrated by @fig-distribution, our corpus is exponentially
distributed over time, with most sentences drawn from recent articles
and the centroid of our *sentences A* would therefore itself be skewed
toward recent language. Consequently, the sentences retrieved in set
*B*, those closest to the centroid of *A*, would predominantly come from
recent periods. In other words, our results would reflect a modern
understanding of rationality, at the expense of earlier conceptions of
the concept.

To mitigate this presentist bias, we adapted the way sentence similarity
is computed across time (see @fig-rv-method-diagram in the appendix for
a visual representation of our approach). Instead of comparing a
sentence from, say, 1910 directly to a single representative vector
constructed from all sentences in the corpus containing "rationality" or
"rational," we construct time-specific representative vectors. For each
year, we compute a moving-centroid embedding using a symmetric five-year
(11 years) window, based on all the sentences containing "rationality"
or "rational."[^17] Concretely, for the year 1910, we averaged the
vectors of all sentences containing "rationality" or "rational" from
1905 to 1915.[^18]

This procedure yields a period-specific reference vector that reflects
how these terms were used at that particular moment in time. A sentence
from 1910 is therefore evaluated not against a general, and likely
contemporary, meaning of rationality, but against its historically
situated usage. We call these centroids the *representative vectors.*
They should be interpreted as operational summaries of the semantic
contexts in which "rationality" appears within a given symmetric
five-year window, rather than as fixed theoretical definitions of the
concept. While the representative vectors are not associated with any
real sentences, they are close in the vector space from real sentences.
This method allows for the identification of discussions on rationality
across large corpora at low computational cost. For illustration,
@tbl-illustrative_sentences reports the 5 sentences closest to the
representative vector, ranked by cosine similarity for the years 1910,
1950, and 2000.

Thus, from our meta-corpus, we built a first sub-corpus, that we call
the *sentences-corpus*. For each year, we select the 1% of sentences
from our meta-corpus whose embeddings are closest to the corresponding
representative vector.[^19] This sentences-corpus is composed of 499,157
sentences that will be used for subsequent textual analysis to identify
*semantic clusters* on rationality.

We built a second corpus, at the document level, that we call the
*articles-corpus*. We extract from our meta-corpus the *documents* that
are closest to the corresponding representative vector. Because each
article consists of a set of sentences (and thus is represented by a set
of vectors), we can also give a vectorial representation to the article
by computing the centroid of its sentence vectors. We select the 10% of
articles published after 1960 whose centroids are closest to the
corresponding representative vector. This articles-corpus, composed of
25,916 articles, is then used in the bibliometric analysis to identify
*bibliographic communities* from 1960 onwards.[^20] Equivalent to
@tbl-illustrative_sentences but for documents,
@tbl-illustrative_documents displays the five closest documents to the
corresponding representative vectors for years 1910, 1950 and 2000.

@fig-method-schema-general summarises this whole process of building
our two corpora from our meta-corpus and @fig-rv-method-diagram
summarises the construction of the representative vectors.

# **Exploring the corpus** 

## Simple exploration

Before returning to our specific corpora on rationality and diving into
more advanced LLM-based analyses, we first step back and examine simpler
quantitative methods applied to our broader meta-corpus. Indeed,
quantitative approaches come in many forms and levels of complexity.
Quantification does not need to be sophisticated to be useful. Simple
indicators may not always provide the clearest answers to research
questions, but they play an important exploratory role: helping
researchers refine their questions, identify anomalies, or detect
unexpected patterns.

For textual data, term frequency, that is counting how often particular
words or expressions appear, is a straightforward indicator. This metric
has been used repeatedly in the literature, especially to track the
emergence or decline of fields within economics. In well-delimited
domains, term frequency can serve as a reliable proxy for intellectual
dynamics. For instance, @trucNeuroeconomics2023 shows that counting
occurrences of highly specific neuroeconomics terms in economics
journals---such as "striatum" or "prefrontal"---closely approximates
more advanced quantitative measures, and thus provides a simple but
meaningful signal of activity in the field.

@fig-relative-frequency shows the relative frequency (with respect to
the total number of words published each year) of "rational" and
"rationality" in our corpus. The figure reveals a steady postwar
increase of the use of both terms, likely reflecting the progressive
consolidation of rational choice theory in economics. We observe a
marked surge after the 1970s, with a pronounced peak for "rational" in
the 1980s, and a smaller peak for "rationality" in the 1990s. The rise
of "rational expectations" in macroeconomics and the emergence of
behavioral economics following the publication of @kahnemanProspect1979
likely contributed to this pattern. Of course, one can only speculate
about the precise drivers of these trends from such simple metrics.

While our usage of a LLM will shed light on the context surrounding this
upward movement, such context can also be approximated with simple
measures. Co-occurrence analysis helps recover the different
intellectual settings in which rationality is invoked.
@fig-co-occurence reports, by decade, the five words most frequently
adjacent to "rational" or "rationality," showing how these associations
shift over time. Before the 1930s, the picture was heterogeneous. The
notion was tied to the marginalist idea of "calculation," but it
referred not only to individual behavior but also to "system" or
"organization." The discussion was explicitly methodological, as
indicated by the prominence of terms such as "method," "explanation,"
"law," and "foundation." From the 1940s onward, the rise of choice
theory places rationality at the center of economic modeling as a device
for describing and formalizing behavior. This is mostly visible with the
rise of multiple common bi-grams (i.e., combination of two words) that
remain stable from the 1930s through the 1980s such as "economic
rationality", "rational choice", "rational behavior". By the 1970s---and
especially the 1980s---the framework was both extended and contested.
First, the most common bi-gram by far becomes "rational expectations"
signalling the emergence of a new predominant concept extending
rationality. In the 1980s, "rational expectations" appeared 15 more
times than the other most common bi-grams. Second, while the concept
"bounded rationality" was developed by Herbert Simon initially in the
1950s, the concept only became prevalent during the 1990s with the
bi-gram becoming the fourth most common one.

Beyond textual data, citation data also constitute a useful source of
information for corpus exploration. The evolution of an idea depends not
only on how it is formulated by its authors, but also on how it is
appropriated, and reinterpreted by readers. A substantial literature in
citation theory examines how citations function as a scientific practice
and how they should be interpreted [see @tahamtanCore2018 for a
literature review on the issue]. Citations may reflect a wide range of
motivations---from a genuine desire to acknowledge intellectual debt to
more strategic uses aimed at persuading readers or satisfying referees.
Nevertheless, citations at the very least signal a relationship that can
help trace the lineage and diffusion of ideas, even when the reasons
behind the citation are not purely intellectual. Beyond tracing
diffusion, highly cited papers tend to be more visible and attract
greater engagement---a dynamic that reflects the well-known Matthew
effect [@mertonMatthew1968]. Recent work also shows that citations
influence reading behavior and perceptions of quality: highly cited
papers are more likely to be read thoroughly and treated as significant
intellectual contributions [@teixeiradasilvaMatthew2021;
@teplitskiyHow2022; @eikaStarstruck2022].

Historians routinely discuss scientific influence and recognition using
proxies such as major grants, prizes, and honors. For example, Sent's
[-@sent_behavioral_2004] narrative of the transition from the
dominance of rational choice, through the limited success of "old"
behavioral economics (with contributions by, e.g., Simon and George
Katona), to the emergence of "new" behavioral economics is organized
around such milestones. In this sense, citations serve as a
complementary proxy alongside these traditional indicators. For
instance, although both Simon and Daniel Kahneman received the Nobel
Prize, Kahneman ultimately exerted a broader influence on the
discipline---something that is reflected in citation patterns.

@offerNobel2016 distinguished several citation trajectories among Nobel
laureates in economics: those whose citations peak around the award
before declining; "innovators with staying power"; "still rising"
winners honored before their citation peak; and late winners recognized
long after their peak. @fig-rationality-paper-citations illustrates
these dynamics by plotting citation patterns---both across all Web of
Science (WoS) economics journals and within the top five journals---for
four seminal works critiquing the standard conception of rationality in
economics. @simonBehavioral1955 and
@allaisComportementHommeRationnel1953 represent early critiques of
neoclassical rational choice, while @akerlofMarket1970 and
@kahnemanProspect1979 are foundational contributions to what economists
now refer to as "new" behavioral economics. The latter tradition exerted
substantially greater influence than the earlier one, both across all
WoS economics journals and within the top five journals. The contrast
concerns not only the magnitude of influence, but also the timing and
speed of diffusion. Citations to the two "new" behavioral economics
papers increased rapidly and steadily from publication onward, whereas
Simon and Allais reached only modest citation peaks around the time of
their Nobel Prizes---or even later, in the 2000s, amid renewed interest
sparked by "new" behavioral economics. As @offerNobel2016 argue, many
laureates benefit from a "Nobel premium," a modest increase in citations
following the award. Simon and Allais fit this pattern. Kahneman and
Tversky, however, constitute an exceptional case: after the Nobel Prize,
their previously declining citation trajectory reversed and rose sharply
throughout the period under study.

## More advanced exploration

Citation counts are a blunt tool and cannot answer many questions of
interest to historians of economics: Who cites these works? Are they
cited together? In what intellectual contexts do these citations occur?
Moreover, focusing on a small set of references implies a degree of
arbitrariness in the analysis. Likewise, simply counting the words that
appear next to "rationality" tells us little about whether these words
and expressions are used jointly within the same argument or whether
they belong to distinct contexts that mobilize the concept differently.
It also overlooks the much broader vocabulary related to rationality
(e.g., profit maximization, expected utility, social choice).

Most recent quantitative studies in the history of economics rely on
what can be grouped under the label of "unsupervised methods." These
approaches apply algorithms to a corpus---whether textual or citation
data---to generate classifications and assign categories that are not
predetermined by the researcher but that emerge from statistical
patterns in the data itself, which gives the approach its "unsupervised"
character.[^21] Assigning such categories imposes a form of internal
organization on large and otherwise unwieldy bodies of material,
enabling an accelerated or "distant reading" [@morettiDistant2013].
The typical output of these methods is a map of a discipline or research
area, showing how different entities---topics, articles,
authors---relate to one another.

In contrast to unsupervised methods, supervised methods aim to estimate
predefined relationships or reproduce categories specified in advance.
Supervised methods---such as regression models or classification
algorithms---require researchers to formulate hypotheses, define
variables, or establish categories prior to analysis
[@doAugmented2022]. Unsupervised methods rather seek to detect
patterns, groupings, or structures that emerge from the data
itself.[^22] This "discovery" capacity [@grimmerText2022] is
especially valuable in large-scale and long-run historical analysis,
where the relevant categories may be uncertain, evolving, or difficult
to define in advance. In such contexts, imposing predefined
classifications risks introducing categories that are historically
inadequate or anachronistic. Unsupervised approaches therefore provide a
useful way to identify unexpected regularities, semantic groupings, or
intellectual communities before moving to interpretation.[^23]

In this paper, we use unsupervised methods to analyse both the
articles-corpus and the sentences-corpus. The articles-corpus consists
of the 10% of articles whose embeddings are most similar to the annual
representative vectors. To make sense of this large set of documents, we
employ a method that groups together documents mobilizing similar
understandings of rationality. We use bibliographic coupling, a method
commonly employed in the history of economic thought [see e.g.,
@bacciniDoes2025;@claveauMacrodynamics2016; @trucForty2022]. In a
bibliographic coupling network, documents are represented as nodes, and
links between them are weighted according to the number of references
they share. The more references two articles have in common, the
stronger their connection---and, in network visualisations, the closer
they tend to appear to one another. The underlying premise is that
shared references provide a proxy for intellectual proximity. Such
networks make it possible to identify communities of closely related
documents and to delineate the core-periphery structure of a discipline
or research field.

However, citation practices tend to favor more recent works, which makes
it unhelpful for historians to construct a single citation network
spanning an entire century. Following a method that has proven effective
in the history of economics
[@camilottoNavigating2023;@claveauMacrodynamics2016;
@goutsmedtIndependent2023], we therefore split our corpus into
overlapping eight-year windows,[^24] starting in 1960 (1960--1967;
1961--1968; ... ; 2002--2009), and built a series of 43 separate
networks. Using community-detection algorithms [@traagLouvain2019], we
identify groups of documents that share a substantial fraction of
references and therefore have a similar intellectual background; we
refer to these groups as "bibliometric communities." The next step is to
identify communities that persist over time. When two communities from
consecutive networks share many of the same nodes (i.e. articles), we
treat them as instances of the same underlying group---an "intertemporal
bibliometric community." In this way, our bibliometric communities bring
together documents from different periods of time but that are likely to
engage with rationality in similar ways, based on their shared citation
patterns. This method allows us both to *zoom in* on specific
communities at a given period and to *zoom out* by reconstructing the
broader picture of a dynamic intellectual field.[^25]

For textual analysis, we use the sentences-corpus that gathers the top
1% of sentences that are most similar to our annual representative
vectors of sentences with "rationality" and "rational" (see above and
@fig-rv-method-diagram in the appendix). To analyse this corpus, as
with bibliographic coupling, we want a method that groups together our
observations (here the sentences) that employ similar meanings of
rationality. We draw on the literature on semantic change that measures
the change of meaning of words over time [@kutuzovDiachronic2018;
@giulianelliAnalysing2020; @montanelliSurvey2024;
@peritiSystematic2024a]. We therefore cluster the sentence embeddings
using the HDBSCAN algorithm, a widely used unsupervised method for
clustering LLM embeddings.

Because the distribution of identified sentences is strongly
present-biased (@fig-distribution), clustering all sentences at once
would risk over-representing recent periods. We therefore perform
clustering separately for each decade from 1900 onward (merging the
first two decades due to fewer sentences).[^26] As in our bibliographic
approach, we then seek to form larger groups over time, allowing us to
"zoom in" and "zoom out" depending on what we are searching for. Using
the cosine similarity between clusters across decades, we merge the
closest ones into 17 "intertemporal semantic clusters."[^27]

With both methods, we thus obtain a list of "intertemporal bibliometric
communities" (from 1960 to 2009) and "intertemporal semantic clusters"
(from 1900 to 2009). These allow us to identify subgroups within our
corpus across multiple dimensions: different subfields of economics
(e.g., behavioral economics, macroeconomics), different conceptions of
rationality (e.g., bounded rationality, rational expectations), or even,
more heuristically, different methodological traditions (e.g.,
experimental work, econometrics). Both approaches have clear strengths
and limitations. Some are largely inherited from their respective
sources. In our case, citation data cannot be meaningfully exploited
before the 1960s, while our OCR full texts handle formulas and tables
poorly, making economic models---an essential component of our
story---less visible in the semantic analysis.

Ideally, relying on *both* methods serves complementary purposes. First,
comparing the results of different unsupervised computational
approaches---such as LLM-based embeddings and bibliometric
analysis---acts as a form of robustness check. The systematic comparison
of sources and methods is a long-standing principle in historical
research, allowing scholars to triangulate information rather than
depend on a single perspective. Second, the two methods illuminate
different aspects of intellectual history. Full texts reveal the
meanings, contexts, and semantic nuances of rationality as economists
used the concept in their writing, independently of their institutional
proximity or citation habits. Citation data, by contrast, highlight
patterns of intellectual influence and diffusion: who cites whom, how
ideas travel across fields, and where intellectual boundaries lie. It
conveys sometimes a more sociological dimension: scholars tend to cite
the work of people publishing in similar journals, going to similar
conferences, etc. The following sub-section illustrates how we interpret
our results, and how the two methods' complementarity may be useful.

## Interpreting "Results"

Taken together, the textual and bibliometric approaches allow us to
study both the semantic and thematic contexts of the uses of rationality
in economics and the channels through which these ideas circulated
within the discipline. But how should such a "study" proceed? Unlike
simpler quantitative tools, unsupervised methods do not produce
ready-made results but reduce large and complex data to a smaller number
of coherent groups. In our case, they generate statistical
categories---bibliometric communities and semantic clusters---that lack
predefined conceptual "labels." They are created solely on the basis of
statistical similarities, and their historical or conceptual
significance emerges only through subsequent "exploration"
[@simonsLarge2026] and "validation" [@grimmerText2013]. To make
sense of what brings texts together, we therefore need indicators that
identify shared features and help hierarchise the documents to be read
first**.** At the same time, a good knowledge of the corpus and of the
relevant intellectual debates is indispensable for making sense of the
raw computational results, even once they have been informed by a set of
indicators.

This point illustrates again that, whether at the stage of data
construction or in the interpretation of statistical patterns,
quantitative methods demand a continuous dialogue with qualitative
interpretation, grounded in a close reading of the relevant secondary
literature. Only through this iterative back-and-forth can we turn
statistical groupings into meaningful historical insights. This is both
a weakness and a strength. On the one hand, the analysis is not
immediately transparent, as it requires the construction of intermediate
tools---such as our interactive application---to guide interpretation.
On the other hand, it is consistent with the practices of historians of
economic thought, who likewise select, prioritise, and read texts in
order to make sense of their corpus.

A key step for the interpretation of our results is thus the process by
which we *select* and *prioritise* observations that will make sense of
them. To make this crucial step as transparent and replicable as
possible, we have built an application, where readers can explore all
the semantic clusters and bibliometric communities, together with their
corresponding indicators.[^28] Let us take as an example the semantic
cluster we labelled "Rationality and its Limits," which gathers close to
20,000 sentences from 1920 to 2009.[^29] How can we get a sense of what
this cluster actually coalesces around? Before any qualitative
interpretation or contextualization with the secondary literature, we
must first produce a series of indicators to help us characterize the
cluster. We choose the following indicators:

- **The TF-IDF.** We identify words specific to the cluster for each
  decade, based on Term Frequency-Inverse Document Frequency (TF-IDF).
  For instance, while the first period of the cluster (the 1920s) deals
  notably with "rationalisation" and "human reason," the 1950s are more
  directly focused on "rationalism," "rationality," and "rational
  behavior." After the 1970s and until 2009, "bounded rationality"
  emerges as a core concept in this cluster.

- **The closest sentences.** We use two different definitions. First,
  the sentences within the semantic cluster that are closest to its
  year-representative vector. Second, the closest sentences from the
  cluster's centroid itself for each period. The first tends to
  highlight how the concept of rationality is discussed, while the
  second centers more directly on the core semantic content of the
  cluster, often offering clues about the topics and debates that
  animate it in different periods. For instance, in the 1950s, one of
  the sentences closest to the representative vectors is Simon's claim
  that "If man, according to this interpretation, makes decisions and
  choices that have some appearance of rationality, rationality in real
  life must involve something simpler than maximization of utility or
  profit" [@simonTheories1959, 259--260]. As for the closest sentences
  from cluster's centroid, Allan Drazen [@drazenRecent1980, 294]
  warned in the 1980s that "Deciding on the suitable notion or
  definition of rationality is not an easy task," in his survey of the
  disequilibrium-theory literature in macroeconomics.

- **The closest articles**. We define the closest articles as those
  containing the highest number of sentences belonging to the cluster
  within each decade. Here we find, for example, Terence Hutchison's
  "Expectation and Rational Conduct" [@hutchisonExpectation1937];
  Jacob Marschak's "Rational Behavior, Uncertain Prospects, and
  Measurable Utility" [@marschakRational1950]; Herbert Simon's 1978
  Richard T. Ely Lecture at the AEA meetings [@simonRationality1978]
  and his Nobel lecture [@simonRational1979]; as well as Sugden's 1991
  *Economic Journal* survey on rational choice [@sugdenRational1991].
  We also observe that many of these articles are published in
  behavioral-economics journals such as the *Journal of Socio-Economics*
  and the *Journal of Economic Behavior and Organization*. From the
  representative sentences and articles, we can also infer recurring
  authors.

- **The most cited references.** From the 1950s onward, we compute the
  most cited references in the cluster (based on the number of citations
  per article, whether the article has one or ten sentences in the
  cluster). For instance, in the 1950s, one of the most important
  references within this cluster is John von Neumann and Oskar
  Morgenstern's *Theory of Games and Economic Behavior*
  [-@vonneumannTheory1944], while @kahnemanProspect1979 becomes the
  most cited reference in the 2000s.

With all these indicators---and prior to any further qualitative
investigation---we can already identify this semantic cluster as
centrally relevant to our study, since it bears directly on the concept
of rationality itself (hence our label, "Rationality and Its Limits").
Our textual approach is therefore capable of isolating specific uses of
rationality---here, debates concerning the meaning of rationality itself
and the limitations of its application in economics---thereby enabling
us to trace the evolution of these uses over time as well as across
topics and subdisciplines, including game theory, macroeconomics,
behavioral economics, and evolutionary economics.

The bibliometric approach does not allow for such temporal or
cross-subdisciplinary exploration. In our bibliometric communities, no
grouping addresses rationality and its limits in general across multiple
decades. Rather, bibliometric analysis identifies groups of articles
from authors in close academic communities. In relation to the semantic
cluster "Rationality and its Limits", we observe, for instance, the
emergence of the "Behavioral Economics: Risk & Uncertainty" community in
the 1981-1988 window, that remains until the last window (2002-2009). As
with the semantic clusters, for each bibliometric community in each
temporal window we extract equivalent indicators: the most identifying
words, the sentences closest to the representative vectors---based on
the articles belonging to the community---as well as the most cited
references. We also examine the flows of each community in a given
window: that is, whether its nodes derive primarily from the same or
from different communities in preceding periods ("origins") and what
they become in the following period ("destinies").

# **Discussion**

Equipped with these groupings and indicators, we can make sense of our
results. How can they help enrich, complete, and refine our
understanding of the various and evolving meanings of rationality in
economics? This paper does not propose an alternative history of the
concept, which would extend far beyond the scope of this methodological
discussion. Rather, we highlight selected findings that corroborate and
strengthen strands of the existing literature, notably by allowing us to
make claims about the prevalence and timing of considerations about
rationality, while also broadening the scope of that literature and
opening avenues for further research.

Throughout much of the period---but especially before the
1940s---sentences captured by our representative vectors refer sometimes
less to the rationality of economic agents than to the rational
character of economists' arguments, understood in terms of coherence or
sound reasoning. This pattern reflects the logic of our semantic
approach: LLMs tend to associate explicit mentions of rationality with
broader discussions of reasoning and coherence, even when the connection
to later, behavior-centered notions of rationality remains indirect. We
retain this ambivalence deliberately since it reveals both historical
semantic change and the interpretative challenges inherent to
large-scale analysis.

Our goal is also to show how we navigate the results and triangulate
indicators to produce coherent historical narratives. While we rely on
the secondary literature, the articles we foreground are those
identified by our indicators as some of the most significant for
understanding the semantic clusters or bibliometric communities.[^30] We
provide two complementary discussions: a macro-level perspective that
highlights broad patterns in the evolution of rationality, and a
micro-level analysis that focuses on the emergence of a specific
topic---behavioral economics.

## Through the Telescope: Broad Patterns on the History of Rationality {#telescope}

When our quantitative inquiry begins in 1900, the concept of rationality
had already gained prominence, in line with the rise of scientific and
abstract reasoning in the late nineteenth century. The scope of rational
behavior was closely tied to debates on the proper domain of economic
analysis [@giocoliModeling2003]. With the marginalists, the economic
agent was increasingly defined by calculative capacity. Jevons, for
instance, portrayed the agent as a "calculating machine" balancing
pleasures and pains, a view later formalized as utility maximization
[@maasMechanical1999].

In our first two decades, semantic cluster "Utility Theory" represents
discussion centred on utility and brings together insights on marginal
utility from, among others, Sidney J. Chapman, Arthur Pigou, Francis Y.
Edgeworth, and John M. Clark. Cluster "History of Economic Thought &
Philosophy of Economics" also captures discussions about utility that
were framed as interpretations, critiques, or extensions of classical
authors---most notably Mill, Ricardo or Malthus. Yet, if anything, our
results suggest that marginal utility theory appears mostly under severe
criticism in this period, especially from institutionalist economists
such as Thorstein Veblen, Wesley Mitchell, John Maurice Clark, and
Rexford Tugwell.[^31]

The criticism was directed along two main lines. First, as
@giocoliModeling2003[48--50] points out, institutionalist economists
rejected the "unfounded psychological underpinnings of neoclassical
economics" and sought to replace them with sounder foundations [see
also @yonayStruggle2001, 101-106]. They proposed instead to renew the
economic method by drawing on psychology and its emerging "behaviorist"
approach [@rutherfordInstitutional2001, 175--176]. From 1900--1920,
the semantic cluster "Methodological Discussions" captures a significant
share of sentences that address such institutionalist critiques.
Institutionalists were energized by new developments in psychology. In
his review of the literature on "Human Behavior and Economics," Mitchell
emphasized the growing interest of economists in psychological matters,
which stemmed from "a somewhat tardy recognition that hedonism is
unsound psychology, and that the economics of both Ricardo and Jevons
originally rested on hedonistic preconceptions" [@mitchellHuman1914,
1]. For economics, the crucial issue was thus to choose "between
providing a sounder psychological basis for our analysis, and holding
that its psychological basis does not concern the economist" (2).[^32]
Such criticism did not falter in the 1920s. In the cluster "Rationality
and its Limits"---centered at the time on "rationalisation" and "human
reason"---@tugwellHuman1922[317] encouraged economists to move beyond
the "rigid classical *homo economicus*" and noted that "psychologists
have already pretty well revolutionized the scientific definition of
human nature."

A second line of criticism held that institutions were indispensable for
understanding economic behavior, and different institutions implied
different behaviors; there was no single, context-independent *homo
oeconomicus*. In the cluster "Methodological Discussions", in his review
of John Bates Clark's contribution, @veblenProfessor1908[159-160]
argued against the "statical scope and character" of marginal-utility
theory, which, in his view, cannot address "questions of genesis,
growth, variation, process." Similarly, in the cluster "Utility Theory",
E. H. @downeyFutility1910[253] claimed that "Marginal-utility
economics has nothing to say of the genesis, growth, or current working
of economic institutions" [see also @rutherfordInstitutionalist2013,
141]. Its "deliverances," he argued, were therefore "futile for the
problem of social betterment," since such "betterment" concerned the
adjustment of institutions to changing circumstances and ideals. In the
early twentieth century, economic behavior, according to
institutionalists, had to be understood through the prism of the
"pecuniary institutions" that shaped it. For instance, in the cluster
"Methodological Discussions", Charles Cooley [@cooleyProgress1915]
underlined that "pecuniary valuation," or economic valuation, is only
possible because of the institutions that make such valuation possible
[see also @rutherfordInstitutionalist2013, 58--59].
@fig-co-occurence shows well the importance of "pecuniary" as a
neighbor to "rational" and "rationality" in the first twenty years of
the twentieth century.

The centrality of institutionalist economists---as well as the
prominence of U.S. journals in our corpus---is visible in the scope of
the semantic clusters in the first periods: sentences related to
rationality, in addition to the clusters already mentioned, were grouped
into themes related to the railway industry, progressive taxation (see
cluster "Legislation, Regulation & Planning"), tariffs and commercial
policy in the United States (see cluster "Price Theory"), or agriculture
(see cluster "Agricultural Economics"). In line with institutionalism,
most of these economists examined these themes through the laws and
rules governing economic activity, focusing on how institutions
structure the behaviour and interests of collective actors rather than
on abstract individual assumptions. Within these clusters, "rationality"
is rarely invoked explicitly, although discussions of the behavior of
"business men" (cluster "Firm Theory & Entrepreneur"), "workmen"
(cluster "Legislation, Regulation & Planning") or "owners of land" and
"farmers" (cluster "Agricultural Economics") were common. Across
successive periods, however, these thematic configurations declined in
prominence, and most intertemporal clusters associated with them
disappeared after the Second World War. Indeed, the period from 1930 to
1959 displays substantial transformations in the structure of debates
concerning rationality.

The most obvious transformations are those described by
@giocoliModeling2003 as "the escape from psychology" and, more
generally, the shift from a "system-of-forces"---"economic processes
generated by market and non-market forces"---to a "system-of-relations,"
in which the aim becomes to establish the existence and properties of
equilibria through the "validation and mutual consistency of given
formal conditions" [@giocoliModeling2003, 4--5]. "Rationality" was
progressively distinguished from "reason" or "intelligence" and recast
as a formal, axiomatic notion---"rigid rules that determine unique
solutions" [@ericksonHow2013; see also @klaesConceptual2005].

These transformations are visible in the intertemporal semantic cluster
"Utility Theory". While it constituted only a tiny share of sentences
between 1900 and 1919, and was absent in the 1920s, it gained importance
in the 1930s to the 1950s (though still representing less than 5% of all
sentences). During this period, the cluster captures the heart of the
debate concerning the measurability of utility and the opposition
between "cardinal" and "ordinal" utility. In the 1930s, the debate still
bore on the psychological dimension of utility measurement. In 1933,
John Hicks and Roy Allen [-@hicksReconsideration1934] coauthored an
article on demand analysis that eliminated marginal utility by appealing
to the concept of the marginal rate of substitution---the slope of the
indifference curve [see also @moscatiMeasuring2019, 98--100]. Already
in 1932, Allen had made this project explicit: by starting from
"preferential discrimination," or individuals' preferences over
different bundles of goods, it becomes unnecessary to "make any
assumption about the existence of 'total utility' or about the
measurability of 'utility'; the hedonistic hypothesis has been rendered
superfluous" [@allenFoundations1932, 207].[^33] In other words,
"Subjective and psychological concepts have been discarded from pure
economic theory" (ibid.).

Yet this position was not uncontested. Indeed, in the same cluster,
terms such as "introspection," "satisfaction(s)," and "pleasure" recur
frequently during the 1930s and 1940s [see TF-IDF, and, for instance,
@armstrongDeterminateness1939]. But they disappeared from the top
identifying words in the 1950s. During this period, debates on ordinal
versus cardinal utility continued---with a renewed defense of the
cardinalist position and ongoing disputes about the very meaning of
"measuring utility" [@moscatiMeasuring2019, chapter 10]---yet these
discussions had largely emancipated themselves from psychological or
behaviorist considerations. These debates are also associated with a new
intertemporal semantic cluster "Decision Theory", distinct from the
cluster "Utility Theory." Appearing in the 1940s and expanding
substantially during the 1950s---to nearly 8% of all sentences---this
cluster centers on the formalization of agents' preferences and choices.
Here, we encounter what would become the standard vocabulary of decision
theory: "individual orderings," "preferences," "decisions,"
"transitive," etc., and @vonneumannTheory1944, @friedmanUtility1948,
and @savageFoundations1954 are the most cited references by the core
articles of the cluster. To complete this panorama, a separate cluster
"Game Theory" emerged in the 1950s, which ultimately comes to represent
nearly 15% of all sentences after 1990.

Transformations in the conception of rationality are also visible in
intertemporal semantic clusters that persist over time while reflecting
profound shifts in the discipline's methodology and the growing
centrality of rational choice theory*.* For instance, the cluster "Firm
Theory & Entrepreneur" spans the period from 1900 to 1979 and therefore
provides a useful vantage point from which to trace how changing
conceptions of rationality reshaped the treatment of firms' decisions.
In the 1920s, the cluster emphasizes entrepreneurial decision-making,
understood primarily as prudence facing uncertainty rather than formal
optimization. From the 1940s, this cluster increasingly centers on
"profit maximization." The cluster captures the core of the so-called
"marginalist controversy" [@backhouseFriedmans2009], notably through
Richard Lester's attack on marginal theory and Fritz Machlup's
[-@machlupMarginal1946] response. Machlup defended profit maximization
and, more broadly, marginalist theory itself. He rejected the evidential
value of Lester's questionnaire-based surveys of entrepreneurs, while
Lester replied that "at the heart of economic theory should be an
adequate analysis and understanding of the psychology, policies, and
practices of business management in modern industry"
[@lesterMarginalism1947, 146].[^34] More generally, the marginalist
controversy provided a key intellectual background for Friedman's essay
on positive economics [-@friedmanMethodology1953], in which he
formulated the "as if" principle to justify, among other assumptions,
profit maximization. By the 1950s, the most cited articles within the
cluster "Firm Theory & Entrepreneur" were Machlup's
[-@machlupMarginal1946] and Friedman's [@friedmanUtility1948], both
of which relied heavily on "as if" reasoning, notably to justify, in the
latter, the behavior of agents regarding expected utility.[^35]

Shifts in the discipline's methodology are also captured by the cluster
"Methodological Discussions." While in the 1920s and 1930s economists
still engaged with notions such as "human nature," "passions," or
"prejudices," the postwar period saw the growing prominence of terms
such as "logical implications" and "assumptions," followed, from the
1970s onward, by an increasing focus on "models" and "optimality."

It thus becomes clear that by the 1950s the conception of rationality
had been profoundly transformed, moving in a more formal direction and
largely emancipated from psychology. Another transformation also
deserves emphasis: as rationality was recast in terms of consistent
choice rather than as a psychological portrait of *homo oeconomicus*,
the normative dimension expanded---from individual behavior to questions
of social choice and of "rationalizing" policies [@ericksonHow2013;
@handsNormative2015].

The emergence of this social dimension of rationality is already
observable in the interwar period, well before the Cold War. In the
1930s, the concept of "rationalization"---relatively neglected in the
history of economic thought---was central in the cluster "Rationality
and its Limits." In a literature review on this concept, Robert Brady
[@bradyMeaning1932, 526] remarked that "scarcely any term... has
occasioned more discussion and dispute." The concept referred to "every
technique, program, or plan of organization which promised to promote
(...) the 'efficiency' of individual enterprises, entire industries, or
even the total of economic processes nationally or internationally
considered." Attention to "rationalisation" is also visible in the
cluster "Agricultural Economics", with the rise of "farm management"
aimed at improving farmers' living conditions. It becomes even more
pronounced with the multiplication of debates on economic planning and
the rationalization of policy decisions from the 1940s onward,
particularly in the cluster "Legislation, Regulation & Planning."

As rationality increasingly came to be framed through modern
microeconomics, the concept was extended to collective choice. In the
intertemporal semantic cluster "Decision Theory", the rational "decision
making" is applied not only to individuals but also to firms and public
policy. Social choice issues emerge in this cluster in the 1970s,
notably through debates on the implications of Arrow's impossibility
theorem [-@arrowSocial1951; see e.g. @igersheimDeath2019].[^36]
Arrow's contribution also stimulated the formation of the cluster
"Voting & Public Choice" in the 1960s, where it appears as the primary
reference, alongside works by @downsEconomic1957 and
@buchananCalculus1962. This cluster is closely associated with
publications by *Public Choice* [see @cherrierEconomists2017].
Welfare economics and public choice, as well as public finance
[@desmarais-tremblayPublic2023], are also clearly visible in the
bibliometric analysis after 1960. Indeed, one of the major bibliometric
communities of the 1960s is "Public Economics: Externalities" with James
Buchanan, Ronald Coase, and Richard Musgrave as central references. The
prominence of public finance increases further in subsequent decades,
with many communities gravitating around "Public Economics:
Externalities", notably one devoted to optimal taxation after 1968;
taken together, these different "Public Economics" communities account
for more than one fifth of the entire network in these periods.

We have seen how the meaning of rationality progressively transformed
and formalized after the 1930s, and how the rationalization of
collective decision-making became central in the postwar period. So far,
however, we have said little about macroeconomics. Macro-oriented issues
constituted a relatively important semantic cluster from the beginning
of our period, in 1900, notably with the intertemporal semantic cluster
"Monetary Policy & Rational Expectations". This cluster grew in
importance in the 1930s, in connection with debates surrounding Keynes's
work, liquidity preference, and unemployment. It is only in the 1970s,
however, that this cluster becomes dominant in our panorama of
rationality. This shift is closely linked to the emergence of the
concept of "rational expectations," which profoundly transformed the way
rationality was discussed in economics. The concept was developed by
@muthRational1961 but only later popularized when Carnegie
colleagues---Robert E. Lucas, Edward C. Prescott, and Thomas J.
Sargent---applied it to macroeconomics [@lucasExpectations1972;
@sargentRational1973]. By the late 1970s, it had circulated beyond
academia into policy circles and the press, and was often described as a
"rational expectations revolution" [@duarteRise2025]. Our methods help
account for this rapid diffusion beyond controversial policy debates
during the stagflation era. First, the results show no significant trace
of rational expectations in the 1960s in either the bibliometric or
textual outputs.[^37] But from the 1970s onward, it occupies a central
place in the literature on rationality, reaching its apogee in the
1980s, when it accounted for nearly 30% of all sentences in the textual
analysis, as well as a comparable share of articles in the bibliometric
analysis, spread across several bibliometric communities
("Macroeconomics: Business Cycles & RE," "International Macroeconomics,"
and "Macroeconomics: Modelling Consequences of RE").

Finance shows a trajectory similar to macroeconomics. The origins of
financial issues can be traced to the semantic cluster "Capital &
Investment Theory," which focused initially on the theory of investment.
Until the 1930s, the issue was framed around the returns of capital. For
instance, the cluster includes the so-called Hayek-Knight controversy on
the conception of capital [@cohenHayek2003]. After the 1940s,
decision-making under uncertainty became a central theme, crystallized
by works such as George @shackleTheory1942 on investment under radical
uncertainty, which figures among the most representative articles. One
decade later, Jack @hirshleiferTheory1958 inscribed investment theory
within the rising neoclassical conception of rationality, by formalizing
investment decisions as a problem of intertemporal maximization of
consumption*.* In the same vein, the Modigliani--Miller theorem
[@modiglianiCost1958] further consolidated this shift by grounding
firm financial decisions as an arbitrage problem, opening the path to
modern financial economics. Their theorem, they argued, can be used "as
a basis for rational investment decision-making within the firm"
[@modiglianiCost1958, 296]. After the 1960s, the cluster "Capital &
Investment Theory" became much more prominent, accounting for more than
10% of all sentences. In this period, rationality is increasingly framed
in formal decision-theoretic terms and focused on appropriate investment
choices under uncertainty. Hence, our analysis suggests that rationality
in finance enters primarily through corporate finance, rather than
through asset pricing, where rationality seems to have remained an
implicit assumption, rarely discussed explicitly prior to the emergence
of behavioral finance.

However, from the 1980s onward, modern asset pricing became dominant
within the cluster "Capital & Investment Theory" as indicated by the
growing prominence of terms such as "assets," "arbitrage," and "capital
asset pricing". We also observe increasing proximities between the
finance literature and the rational-expectations framework from the
mid-1970s onward. This is visible both in the textual and bibliometric
analysis, in particular with the "Finance: Market Information"
bibliometric community, which emerged in the 1971-1978 window and
focuses increasingly on rational expectations. A central contribution
found in both semantic and bibliometric clusters is
@grossmanImpossibility1980, which draws on Lucas's
imperfect-information framework [@lucasExpectations1972] and combines
rational expectations with noisy signals to question market efficiency.
More generally, rational expectations models---initially developed in a
macroeconomic context---became a central framework for analyzing the
(ir)rational use of information in finance [see
@delceyEfficient2023].

The 1970s and 1980s thus marked a relative dominance of macroeconomics
and finance, with comparatively less weight given to debates on
individual rationality. This situation began to change gradually from
the 1980s onward. In the 1981-1988 bibliometric network, the community
"Behavioral Economics: Risk & Uncertainty" appears (representing around
5% of the network), capturing the early emergence of behavioral
economics as promoted by Kahneman and Tversky. In the 1990s, the rise of
behavioral economics---together with new approaches in game
theory---fundamentally altered this configuration, leading to more
specialized investigations of individual rationality, which now dominate
and are distributed across multiple bibliometric communities. This
transformation represents not merely a shift in research topics, but a
profound reframing of how economics approaches rationality: from an
assumption embedded in theories and models to an object of direct
investigation at the individual level.

We have sought here to offer a broad panorama of the major
transformations in the concept of "rationality" in economics. These
results are largely consistent with an established historiography,
although this approach could be particularly useful in less studied
areas or to assess more accurately the timing of change. Here, it allows
us to identify large-scale changes when they become visible in the
data---namely, when particular clusters come to represent a significant
share of sentences (or of the bibliometric networks). For instance, we
observe that the "social" dimension of rationality became prominent
already in the 1930s, when the issue of "rationalising" economic
processes and policy arose. Still, historians of economic thought are
often concerned with uncovering how such transformations came about:
which contributions, authors, and communities played a decisive role.
Addressing these questions requires a more focused perspective, tracing
the evolution of specific topics and literatures. This is the aim of the
next section, which moves beyond the panoramic view to provide a more
detailed narrative of the rise of behavioral economics outlined above.

## Under the Microscope: Simon's Reception and the Birth of Behavioural Economics

The term "behavioral economics" has a complex history. While it is now
mostly associated with the work of Kahneman and Amos Tversky, George
Katona is often credited as an early adopter of a behavioral approach
[@giladEconomic1984; @hosseiniGeorge2011]. To distinguish among
different strands of behavioral economics, @sent_behavioral_2004
proposed an influential distinction between "old" and "new" behavioral
economics. This distinction separates the heterogeneous and reformist
efforts of Katona, Simon, and others to challenge mainstream economics
from the more homogeneous heuristics-and-biases research program
developed by Kahneman and Tversky. Sent argues that "new" behavioral
economics succeeded in part because it was less radical than earlier
approaches and because it emerged in the 1980s, at a moment when
economic theory faced multiple epistemological challenges, thereby
creating an opportune context for alternative frameworks.

Why did these two conceptually-related research programs follow such
different trajectories and levels of influence in economics? Both
challenged standard assumptions of rationality under the banner of
behavioral economics, and both were ultimately recognized with Nobel
Prizes, yet their patterns of reception and adoption differed. While our
methods cannot identify the comprehensive mechanisms behind this
divergence, they allow us to trace and compare the trajectories of
reception and influence of these two approaches, shedding light on how
and when they followed different paths.

Our analysis suggests that Simon's concept of "bounded rationality"
stands as one of the most influential critiques of standard rationality
in economics, particularly in its role in structuring debates about
rationality itself. Simon's work dominated discussions in the 1960s and
1970s, with his seminal articles [@simonBehavioral1955;
@simonTheories1959] and his Nobel lecture [@simonRational1979]
appearing across a wide range of research areas, from social choice
theory to the theory of the firm and price setting. The textual analysis
highlights Simon's conceptual centrality. The semantic cluster
"Rationality & its Limits" undergoes a marked transformation following
the rise of Simon's influence. In the 1950s, the TF-IDF associated with
this cluster was centered on terms such as "rational behavior,"
"rationalization," and "irrationality." By the 1970s, "bounded
rationality" had become one of the most prevalent expressions in the
cluster, and by the 1990s, references to "boundedly rational agents" and
"procedural rationality" clearly positioned Simon's concepts at the core
of economic discussions, reflecting a delayed but substantial
integration into the discipline.

Moreover, Simon's impact is visible not only in the changing language of
rationality but also in the growing prominence of these debates within
economics. The cluster "Rationality & its Limits" expands from 5.76% of
all sentences in the 1950s to 7.85% in the 1980s, peaking at 9.56% in
the 1990s. This growth signals a significant increase in the attention
devoted to foundational questions of rationality. Citation analysis
corroborates this pattern of late recognition: references to
@simonBehavioral1955 rise gradually after publication, with citation
peaks occurring only in the post-2000s period (see
@fig-rationality-paper-citations).

However, Simon's influence remained limited in two critical respects.
First, the slow diffusion of his framework meant that, by the time it
achieved broad conceptual prominence, it faced direct competition from
"new" behavioral economics, present in the semantic clusters "Decision
Theory" and "Decision Under Uncertainty", as well as in "Consumption,
Savings & Intertemporal Choice" and "Game Theory". All of these four
clusters expanded rapidly in the 1980s, with most of them individually
surpassing cluster "Rationality & its Limits" in their share of
sentences. Although these strands incorporated elements of bounded
rationality, they did so primarily through the conceptual tools of "new"
behavioral economics---ranging from prospect theory in the analysis of
risk to experimental paradigms such as the ultimatum game in game theory
[@gualaParadigmatic2008].

Second, Simon's conceptual influence, spearheaded by bounded
rationality, never translated into stable bibliometric communities.
While his framework shaped how many economists approached rationality,
very few actually developed the research program he initiated. In our
bibliometric networks, only small, unstable communities formed around
Simon's work. In the 1960s and early 1970s, his ideas appeared in
*Public Economic* communities, operations research circles and
behavioral theories of the firm (*cl_165*) and critique of the standard
profit-maximizing such as socialist enterprise theory (*cl_123*). Simon
was generally associated with other researchers critical of perfect
rationality: @winterSatisficing1971, which applied satisficing to firm
behavior; @cyertCompetition1969 on behavioral theory of the firm; and
@leibensteinAllocative1966 on "X-efficiency," challenging economics\'
focus on allocative efficiency (*cl_179*). Together, Simon, Winter,
Cyert, and Leibenstein formed a diverse organizational theory critique
of how rationality, especially through profit maximization, is employed
in economics. While this collective movement had some momentum, none of
these research programs had an individual effect on economics structure
[see also @sent_behavioral_2004]. After 1969-1976, these different
research streams coalesced into a small short-lived community (*cl_258*)
before fragmenting. References to Simon and critiques of profit
maximization remained scattered, moving through several small
communities (e.g., *cl_793* on post-Keynesian economics, *cl_755* on
contract theory, *cl_773* and *cl_614* on institutionalist approaches)
without ever achieving critical mass. While Simon's influence in
economics was conceptually enduring, it remained marginal and unable to
generate coherent, large and stable bibliometric communities.

The reception of "New" behavioral economics reveals a contrasted
pattern. Unlike Simon's trajectory, the heuristics and biases research
program of Kahneman, Tversky, and other "new" behavioral economists
generated multiple stable clusters that formed well-identified and
substantial research communities. A main "Behavioral Economics: Risk &
Uncertainty" cluster emerged in 1981-1988, structured by early adopters
of the new approach. The crystallization of this distinct cluster
signaled the beginning of explosive growth and the spinning off of
several autonomous communities that captured emerging specialized areas
of behavioral economics: pro-social behavior (*Behavioral Economics:
Social Preferences*) and behavioral game theory (*Game Theory:
Behavioral*), intertemporal decision-making and risk (*Behavioral
Economics: Risk & Uncertainty*), and behavioral finance (*Finance:
Behavioral Finance*). In many cases, behavioral economics clusters come
to outgrow or replace existing clusters (e.g., game theory, decision
theory).

By the 2000s, behavioral economics had become the dominant venue for
research on rationality. Three behavioral economics communities
represented nearly 30% of the entire network, with many additional
communities structured by behavioral economics research without being
explicitly characterized as such. The scale and speed of acceptance
differed dramatically from Simon's experience. By 1980,
@kahnemanProspect1979 had already surpassed @simonBehavioral1955 in
annual citations (@fig-rationality-paper-citations). By 1985, prospect
theory had already surpassed the lifetime citation peak that Simon's
work would ever reach within economics. By the 2000s, most microeconomic
publications addressing rationality were explicitly connected to the
behavioral economics research program. While bounded and procedural
rationality remained frequently invoked concepts, no subsequent research
community clearly carried Simon's legacy as a stable bibliometric
anchor.

Our quantitative study suggests two points regarding the contrasting
influence of Kahneman and Simon. First, the temporal patterns of
adoption differ radically. For the historian @heukelomBehavioral2014, a
pivotal moment in the history of behavioral economics was the explicit
creation of research programs within the Sloan and Russell Sage
Foundations between 1984 and 1992, notably fostering the
Kahneman--Thaler collaboration that decisively transformed the field's
trajectory. Our analysis, however, suggests that a distinctive dynamic
was already underway by the early 1980s in the reception of Kahneman and
Tversky's work. Despite the fact that @kahnemanProspect1979 was the
duo's only publication in an economics journal until 1985---well before
the Sloan--Russell Sage programs formally institutionalized behavioral
economics---prospect theory experienced rapid and sustained citation
growth (@fig-rationality-paper-citations).[^38] Moreover, as early as
the 1978--1985 bibliometric network, we identify an autonomous cluster
structured around their work (cl_391), indicating that the article not
only attracted citations but quickly catalyzed new research strands, in
a way Simon's work never did within economics [@heukelom_sense_2012].
Hence, while the institutional structures that came after played an
important role in the subsequent reception of the research program as a
whole, the reception of Kahneman and Tversky's seminal paper was already
important just after its publication.

The second point concerns the relationship between "old" and "new"
behavioral economics. Contrary to narratives of rupture or forgetting,
citations to @simonBehavioral1955 have never been as high as during the
rise of new behavioral economics---a paradoxical pattern given recurrent
claims that the field has neglected its intellectual roots.
@earlPrinciples2022[2] criticizes this apparent amnesia:

> Neither Kahneman nor Thaler have sought to promote earlier behavioral
economics alongside more recent work. Instead, they give the impression
that behavioral economics started around 1979--1980 with the publication
of Kahneman and Tversky's (1979) article on prospect theory ... a cynic
might suggest that it looks rather as if the earlier work has been
airbrushed from the history of economic thought by the strategic
redefinition of what constitutes behavioral economics. A more charitable
and reflexive view would see the situation as resulting from
insufficient familiarity with the earlier literature.

The surge in citations to earlier works by Simon and Allais reveals a
tension: while "new" behavioral economists often overlook the
contributions of their predecessors, the field's rapid expansion has
paradoxically amplified attention to these earlier works---far beyond
the recognition they received upon publication. This pattern supports
three competing interpretations, each with distinct implications for the
discipline's trajectory.

First, the trend may reflect a genuine revival of abandoned research
directions, suggesting a long-overdue reconciliation between old and new
behavioral economics. This aligns with calls by @sentRationality2008
and @earlPrinciples2022 to reintegrate older insights into contemporary
frameworks. Second, the citations could signal intellectual
appropriation, where classic works are selectively reframed to serve
modern agendas. As @monginAllais2019 argues, this risks distorting
historical contributions through a presentist lens, prioritizing
contemporary relevance over historical fidelity. Third, the surge in
citations may instead represent a backlash against the "new" behavioral
program, with defenders of earlier traditions invoking Simon and Allais
to challenge the hegemony of heuristics-and-biases frameworks
[@vranasGigerenzers2000]. Here, citations function less as homage than
as rhetorical weapons in an ongoing contest over the field's direction.

A definitive assessment of this dynamic will require both deeper
qualitative analysis---such as archival work or interviews to uncover
latent influences---and targeted quantitative studies, including
finer-grained tracing of "old" behavioral economics' intellectual
footprint. This goes beyond the scope of this article. Yet our findings
provide a roadmap for future research, one that highlights the
ambivalent relationship between the field's past and present. The sparse
and fragmented citation patterns we observed for "old" behavioral
economics suggest appropriation rather than integration. Our
bibliometric networks reveal that neither Simon nor researchers
associated with his ideas formed stable or influential communities
within the broader landscape of "new" behavioral economics. Instead,
their ideas appear as isolated echoes, rarely shaping the field's core
structures.

This disconnection becomes even clearer in the last years of our study.
Key concepts from "old" behavioral economics are largely absent from the
dominant vocabularies of "new" behavioral economists, particularly in
clusters "Game Theory" and "Decision Theory." Where such ideas *do*
appear, they are marginalized---confined to heterodox or
institutionalist spaces, such as the 2000--2009 cluster "Rationality and
its Limits." Even the invocation of "old" behavioral economists follows
a pattern of selective framing: figures like Simon are coupled with
canonical critics of standard rationality (from Adam Smith to Allais) in
the bibliometric community "Behavioral Economics: Social Preferences,"
(2002-2009) not to engage with their substantive contributions, but to
anchor "new" behavioral economics within a longer tradition of dissent.
Simon's legacy thus seems to endure primarily as a symbolic
touchstone---a rhetorical device for situating debates and constructing
intellectual genealogies---while his analytical framework remains
superficially absorbed, if not sidelined.

# **Conclusion**

This article is first and foremost methodological: it aims to
demonstrate, through a concrete application, the usefulness of
quantitative methods for the history of economic thought. Nonetheless,
it does so by breaking new ground in the history and philosophy of
economics. First, the corpus we build---comprising nearly 260,000
full-text economics articles spanning more than a century---is, to our
knowledge, the largest and most comprehensive database ever used to
study economic contributions in English. Second, this article
constitutes the first application of quantitative methods to the study
of "semantic change" within the history of economics, an area that
represents an important and growing strand of the literature on
quantitative text analysis [@montanelliSurvey2024]. Third, we also
provide a LLM-based measure to select corpora, with a time component
(the representative vectors) that goes beyond building a raw set of
keywords.

Our approach allows us to identify, within this corpus, the sentences
most closely associated with the words "rational" and "rationality" and,
by extension, the articles most likely to engage with rationality in one
way or another. By allowing the algorithms to identify dozens of
semantic clusters and bibliometric communities within short temporal
windows (eight years or a decade), and by then aggregating these
groupings over time and characterizing them through multiple indicators,
we can conduct analyses at different scales. This makes it possible both
to *zoom out*, by examining the overall configuration of clusters across
periods, and to *zoom in*, by focusing on subsets of clusters more
directly concerned with rationality. As shown in the previous section, a
panoramic view that considers all semantic clusters may initially
include groups that appear only loosely connected to
rationality---especially in the early decades. While examining these
clusters can be informative for understanding the broader intellectual
context, the analyst can also foreground more explicitly
rationality-oriented clusters when addressing more targeted research
questions. This flexibility is only possible because the initial corpus
is sufficiently inclusive, reducing the risk of overlooking relevant
developments. More generally, our approach allows the scale of analysis
to be adjusted to the question at hand, rather than imposing it ex ante.

We want to conclude by drawing several general methodological and
historiographic points from the approaches developed in this article.

First, although quantitative methods in the history and philosophy of
economics have been applied mainly to the postwar---and often
post-1970s---period, our study shows that they can also be used
effectively for earlier periods. Despite problems of text recognition in
JSTOR articles prior to the 1930s, our methods nonetheless provide a
fine-grained depiction of economic debates in the early twentieth
century. In particular, we were able to recover most of the
institutionalist contributions on rationality highlighted by
@rutherfordInstitutionalist2013 and @yonayStruggle2001. At the same
time, our results bring to light additional contributions not covered in
these accounts, thereby opening avenues for further inquiry. Of course,
some important works remain absent because they were published as books
rather than journal articles. This limitation suggests that extending
the corpus to include books would be a worthwhile direction for future
research.

Second, a key property of groupings produced by unsupervised methods is
that they bring together documents that share cognitive content without
presupposing agreement. The texts clustered together address the same
objects or problems, but they may do so in divergent, and sometimes
opposing, ways. As a result, our methods make it possible to identify
sites of resistance to dominant models or ideas. What emerges most
clearly are the objects that attract sustained attention; within those
sites, one can then examine who endorses, revises, or contests
particular ways of treating them. This feature opens the way to a more
"symmetrical" historical analysis [@bloor1976], one that gives
analytical weight not only to intellectual "winners" but also to those
whose positions did not ultimately prevail.

Finally, these methods are also "discovery tools." While they can be
used to confirm or challenge existing claims in the history and
philosophy of economics, they also help identify patterns that have so
far been absent---or only marginally present---in the historical
literature. We have briefly pointed to some of these patterns above. By
making available an interactive application to explore our results, we
hope to encourage readers to pursue their own paths of discovery within
the corpus.

[^1]: In this perspective, our purpose is similar to
    @claveauSocial2018.

[^2]: The bibliometric communities, identified through network analysis,
    could also be called clusters. But we opted for "communities", a
    term often used in network analysis, in order to distinguish them
    from the "semantic clusters."

[^3]: To be clear, we don't think that quantitative methods are only
    helpful for very large corpora. However, it is where their surplus
    value may appear as the most obvious.

[^4]: The application is available in the GitHub repository:
    [https://github.com/tdelcey/ejhet_quanti_method_app](https://github.com/tdelcey/ejhet_quanti_method_app).
    A public version is available at the following url:
    [https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/](https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/).

[^5]: One of the main challenges for the quantitative history of
    economics is to move beyond reliance on proprietary digital
    libraries and to actively develop open, historically inclusive
    corpora. This includes incorporating materials produced in
    non-Anglophone countries and expanding the range of textual formats
    considered---such as books, book reviews, working papers, and
    conference proceedings.

[^6]: Elsevier API allows users to retrieve the full text of Elsevier
    journals such as the *European Economic Review*, provided that users
    have institutional access to the relevant issues.

[^7]: ISTEX allows us to retrieve economics journals not available
    through JSTOR or Elsevier API, such as the *Journal of Economic
    Theory* and to access specific issues of Elsevier journals for which
    we lack institutional access (e.g., the *European Economic review*
    before 1997). For more detailed information on the collection of
    data, see the appendix.

[^8]: Bibliometric and textual data themselves have a history; they are
    "made by institutions, through human processes"
    [@guldiDangerous2023, 34]. Whether digital or material, archives
    are shaped by "distortions" and \"occlusions,\" and the processes
    through which they are constituted are themselves worthy subjects of
    historical investigation [@dastonSciences2012].

[^9]: The programming dimension of such computational approaches enable
    iterative feedback between analysis and corpus cleaning
    [@nelsonComputational2020]; critical scrutiny can therefore be
    continuously exercised at each stage of the research "pipeline"
    [@leeRole2020].

[^10]: Indeed, most textual methods are designed to identify
    commonalities within texts that share a specific linguistic
    structure. Hence, the same topic discussed by two documents in two
    different languages will likely not be identified as related because
    linguistic differences mask underlying semantic similarity**.**

[^11]: For further details on the matching process, see the appendix,
    particularly, @tbl-wos-match-decade. A failure to match an article
    in WoS does not necessarily indicate an error in the matching
    procedure; it may simply reflect the absence of the article in the
    WoS database. This is notably the case for certain JSTOR-indexed
    journals---particularly those that are no longer published---which
    are not covered in WoS.

[^12]: Adding these other outlets would pose additional challenges. For
    both working papers and, above all, books, no large-scale databases
    provide comprehensive full texts or complete reference lists. In
    addition, working papers raise the problem of potential double
    counting, as they may eventually be published in economic journals.

[^13]: We did not filter journals by language a priori. Indeed, many
    non-anglo-saxon journals also publish English articles at some more
    or less frequent occasions. It was thus easier to filter by language
    a posteriori and at the document level, once articles were
    collected.

[^14]: Our goal here is not to provide the reader with extensive details
    on what these models are and how we use them (see the appendix for
    additional details and references), but rather to provide general
    intuitions about the use of LLMs, to understand the building of our
    corpus.

[^15]: Henceforth, "similarity" between sentences or documents refers to
    cosine similarity.

[^16]: Moreover, the texts used to train these models are not primarily
    academic articles in economics. This means that there may be
    important gaps between the general language patterns the model has
    learned and the specific vocabulary, concepts, and writing practices
    of our "domain" [see e.g. @zhangEconBERT2025].

[^17]: Centroids are widely used in the literature on "semantic change"
    to represent the average embedding of a temporal slice or a cluster
    of a corpus [@montanelliSurvey2024]. We adopt the centroid rather
    than the medoid (i.e. the observed sentences whose embedding is
    closest to all others in the set), as the centroid smooths over
    idiosyncratic variation across sentences, whereas the medoid may be
    disproportionately influenced by a single atypical example. While
    the medoid is an embedding of a real sentence and is easily
    interpretable, it is straightforward to compute the closest vector
    from the centroid (see @tbl-illustrative_sentences).

[^18]: We initially tested a symmetric two-year window. However,
    particularly in the early periods, this specification resulted in
    substantial volatility in average usage of the terms "rational" and
    "rationality", thereby increasing the number of "noisy" sentences
    (i.e. sentences not clearly related to rationality or tied to highly
    specific issues). Conversely, longer windows would reduce the
    advantages of our historical approach, as they would blur temporal
    variation too much, especially given the rapid growth of the corpus
    after the 1960s.

[^19]: The choice of the 1% quantile reflects a trade-off between false
    positives and false negatives. We observed that a more restrictive
    threshold (e.g., 0.5%) excludes many sentences that obviously deal
    with rationality in economics, whereas a more permissive threshold
    (e.g. 2%) includes sentences that are too distant from our core
    focus, particularly in earlier periods. The 1% threshold therefore
    appeared as a reasonable compromise. Moreover, a moderate number of
    false positives does not substantially threaten the analysis, since
    such sentences are likely to be later classified as "noise" by the
    HDBSCAN algorithm.

[^20]: The "articles-corpus" only starts in 1960, because the
    bibliographic data from WoS are too limited prior to this date to be
    reliably used.

[^21]: "Unsupervised" does not mean that the modeller has no influence
    on the output. The analyst must choose a particular model and its
    parameters and these choices embed methodological priors about the
    types of patterns the procedure is likely to reveal. For instance,
    one crucial parameter in many unsupervised models is the number of
    categories that will emerge from the algorithm. We detail and
    justify the different parameters chosen for our methods in the
    appendix.

[^22]: See @simonsLarge2026 for a discussion of using LLMs with
    unsupervised or supervised methods in the history and philosophy of
    science.

[^23]: That does not mean, however, that an unsupervised algorithm can
    be applied blindly to historical questions: a substantial part of
    our effort has consisted in adapting the method to our historical
    data, especially to accommodate the growth of the corpus over time.

[^24]: The eight-year window for defining bibliometric communities
    aligns with established practices in the quantitative history of
    economics [@claveauMacrodynamics2016], where timeframes typically
    range between 5 and 10 years [@abramoAssessing2011]. Given that
    economics exhibits longer citation lifespans than the natural
    sciences [@lariviereLongterm2008; @aistleitnerCitation2019], and
    considering the multi-decade scope of our study, we opted for a
    window longer than five years. This choice balances granularity with
    the need to capture enduring citation patterns, avoiding the coarser
    resolution of a 10-year window.

[^25]: Refer to the appendix for details.

[^26]: We don't use overlapping windows in this case, notably for
    computational reasons: finding HDBSCAN clusters on a set of tens of
    thousands of sentences is much more computationally intensive than
    finding bibliometric communities for at most a few thousands of
    articles.

[^27]: Refer to the appendix for details.

[^28]: The application is available in the GitHub repository:
    [https://github.com/tdelcey/ejhet_quanti_method_app](https://github.com/tdelcey/ejhet_quanti_method_app).
    For non technical-users, a public version is available at the
    following url:
    [https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/](https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/).

[^29]: One step in the discovery and interpretive process is often the
    assignment of "labels" to clusters in order to facilitate the
    interpretation of visualizations. We assign manually a label to each
    intertemporal semantic cluster and bibliometric community after
    qualitative inspection.

[^30]: Of course, as in any historical inquiry of this kind, we are not
    entirely protected from selective emphasis, all the more so given
    that the scope of our study is too broad to summarize every pattern
    revealed by our results. Other scholars could have, at various
    junctures, pursued different interpretive directions on the basis of
    the same indicators (especially most similar sentences and
    articles). The publication of the [interactive
    application](https://019adac8-81d4-aa0e-808c-08861c261fd2.share.connect.posit.cloud/)
    we used to explore the results thus serves as an exercise in
    transparency and---in addition to being, we hope, useful for
    historians of economic thought more generally---allows readers to
    assess the robustness and limits of our narrative.

[^31]: However, because we focus on English, published articles, our
    clusters are biased toward American journals, notably in the first
    decades.

[^32]: Some years earlier, @mitchellRationality1910[97] already
    pushed forward similar claims, regretting that "few economists have
    regarded the study of psychology as a necessary part of the
    equipment of their work," often relying on "tacit preconceptions"
    rather than than seeking "psychologists to gain a knowledge of the
    mind and its modes of operation."

[^33]: See closest sentences to the "Utility Theory" cluster's centroid.

[^34]: Machlup's position was that even if a "goodly portion of all
    business behavior may be non-rational, thoughtless, [or] blindly
    repetitive" [-@machlupMarginal1946, 520], questionnaire evidence
    and empirical findings more generally did not demonstrate the
    failure of marginal theory when properly interpreted. In a similar
    defense of profit maximization, Leonid @hurwiczTheory1946[110]
    first acknowledged that it was not "inconceivable that business is
    run more by routine than by rationality," but argued that behavior
    may appear irrational or merely "routine" from the standpoint of a
    purely static theory that ignores uncertainty, while proving fully
    "rational" once uncertainty and long-run effects are taken into
    account [see also @herfeldTheories2018].

[^35]: The cluster "Firm Theory & Entrepreneur" nevertheless remained a
    site for critiques of profit maximization. During the 1960s and
    1970s, contributions that proposed alternative frameworks for
    explaining firms' decisions were highly cited [such as
    @simonTheories1959] or appeared among closest articles from
    centroid [like @winterSatisficing1971].

[^36]: This grouping of sentences in the 1970s actually took its origins
    in the cluster "Utility Theory" (which ended in the 1960s) with a
    focus on welfare economics.

[^37]: This highlights a key caveat of our methods. Because these
    methods foreground statistically "significant" patterns and
    indicators' prevalence, they are not always well suited to tracing
    and interpreting the origins of a concept or theory with the care
    that close historical study and archival research provide.

[^38]: This aligns with a general finding in scientometrics that
    citations in the first two years after publication explain more than
    half of the variation in cumulative citations
    [@sternHighRanked2014]
