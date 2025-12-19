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
and challenging to integrate into research specific to the history and
philosophy of economics.

Our contribution sits between a historical study that uses quantitative
methods to answer a specific question and a general methodological
discussion of those methods. From the collection of data to the
interpretation of results, we illustrate concretely how these methods
are useful and examine, in practice, the methodological choices they
entail. We present a step-by-step application of specific quantitative
methods to a broad topic: the history of rationality in the twentieth
century.

We focus our discussion on unsupervised methods that have been
particularly influential in the history of economics. Unsupervised
methods are machine-learning techniques in which algorithms identify
patterns from unlabelled data, as opposed to supervised learning
methods---such as regressions---that learn patterns from labelled data
to make inferences. The goal of unsupervised methods is not necessarily
to provide a "measure" [@grimmerText2022]---though they can be adapted
to do so---but to organise in categories large corpora and enable
accelerated and "distant reading" [@morettiDistant2013;
@guldiDangerous2023]. They are well suited to historical inquiry
because their unsupervised nature reduces the risk of presentism: rather
than imposing present-day categories on the past, unsupervised
algorithms uncover patterns directly from the data. When time is
explicitly incorporated, they allow researchers to map the discipline at
different points of time, to identify the emergence and decline of
subjects and concepts, and to assess the influence of specific
economists or ideas.

Our article uses two types of data, texts and citations. The analysis of
textual corpora offers a direct window into the semantic content of
debates, while citation data provides a lens through which to view
intellectual interconnections and channels of influence within the
discipline. We show how a large corpus of documents can be classified
based on the information contained in textual and citation data---what
we call "semantic clusters" and "bibliometric communities."[^1]

Above all, our discussion aims to illustrate a core principle for
historical inquiry with such unsupervised quantitative methods. They
require continuous back-and-forth between aggregate quantitative
results, complementary indicators used for interpretation, and
preliminary knowledge and close reading of primary and secondary
sources. These methods function not only as a form of corroboration but
also as "discovery methods" [@grimmerText2022]: they facilitate the
exploration of large datasets to reveal historical patterns. They often
confirm, and sometimes complement, established findings. They can also
reveal pitfalls and blind spots in existing research.

The concept of "rationality" is an effective focus for a concrete
demonstration. First, many historians of economics engage with it in one
way or another, which makes the exercise relevant for a broad audience.
Second, because the concept is broad and pervasive in economics,
applying quantitative methods to a very large corpus is particularly
informative.[^2] We use a corpus of around 290 000 articles in economics
extending back to 1900 to show how these methods can handle long time
horizons. Third, the multiple meanings attached to "rationality" and its
uses applied to various subjects show how textual methods, coupled with
bibliometrics, can help capture this semantic plurality.

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
reflection on broader methodological issues faced by historians of
economics in quantitative inquiries.

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
affiliations, *etc*. Some of these databases, such as *Web of Science,
OpenAlex,* or *Scopus,* record citation data, which enables tracing
intellectual influence through diffusion patterns, and mapping scholarly
contributions over time.

Each database has its own strengths and weaknesses. While at a very
general level Web of Science, OpenAlex, or Scopus have similar coverage
[@martin-martinGoogleScholarMicrosoft2021; @culbertReference2025],
some studies might suffer from choosing a less appropriate database
regarding the research questions. For instance, Scopus has a lower
coverage of the top 5 economics journals before the 1990s and while
being openaccess, OpenAlex has been less curated than the products of
private publishers. Whatever the provider, less successful or
now-defunct journals are also more likely to have incomplete or
discontinuous digital coverage, impeding their inclusion for historical
analyses. Additionally, databases are oriented toward English-speaking
contributions; these databases may thus be deficient for a research
project targeting another or multiple languages.[^3] More generally,
citation practices have only standardised progressively in the postwar
period. Consequently, citation data are most of the time relatively poor
before the 1960s. Last but not least, although they provide useful
metadata and citation information, these databases generally lack full
text, which is subject to copyright and therefore cannot be obtained
from a single publisher.

Even when citations and full texts are available, the amount and quality
of information that can be reliably encoded remain limited. Citation
data are notoriously difficult to structure, because both the very
notion of what constitutes a reference and the conventions governing its
recording have changed over time---for instance, from references
embedded in footnotes to the development of standardized bibliographies
and the author--date system [@graftonFootnote1999]. Full texts face
similar limitations: mathematical expressions and empirical material,
such as tables, are often poorly captured or inconsistently encoded by
providers. These shortcomings restrict what can be studied by
quantitative tools.

A first important point is, therefore, that data availability shapes
what can be asked and so answered. The scarcity and structure of
available data affect every stage of inquiry, from the choice of
research questions to the interpretations of quantitative results. In
practice, research may be shaped as much by the scarcity of our data as
by researchers' own preferences. It is of course possible to build
handmade datasets from scratch, but, in the case of textual and citation
data, such tasks remain time-consuming beyond small-scale study. More
commonly, it is often necessary to combine information from different
databases to fulfill a specific goal. For example, a medium-scale study
of the publications of the European Economic Review
[@goutsmedtIndependent2023]---few thousands documents---required to
combine three heterogenous databases: Econlit (for JEL codes
classification) Web of Science, and Scopus (due to imperfect coverage of
Web of Science).

For our study of rationality, the first step was to identify the best
sources. For citation data, the Web of Science (WoS) provides the most
reliable and consistent coverage for our period and has been widely used
in the history of economics. As for full text, we relied on three
providers. First, JSTOR's full-text collection offers high-quality scans
of most leading economics journals. Second, we used Scopus to identify
peer-reviewed economics journals not included in JSTOR and to compile a
complementary list of articles; for these, we retrieved full texts first
through the Elsevier Full-Text API, when available. Third, remaining
full texts were obtained through the ISTEX project, which provides
access to a substantial corpus of documents for researchers affiliated
with French universities.[^4]

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
transform them into a usable database. While WoS citations are already
delivered in a relatively structured form, full texts require
substantial processing. In most cases, data are not given but result
from a process that involves cleaning, categorizing, and selectively
removing or reformatting information from raw sources in order to
produce a dataset suitable for computational analysis. This challenge is
particularly true in the history of economics, where the primary sources
are the texts themselves---often unstructured and interspersed with
various layers of textual content, such as section headings, footnotes,
bibliographic references, or editorial annotations. This requires making
important choices well before the actual stage of analysis.

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
and data tables.

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
that should be made explicit and required to engage with some of the
material available.

To give an illustration, it is only after a first batch of exploratory
analysis that we notice that some important economics journals were
missing in JSTOR. If it was obvious from preliminary results that the
emergence of behavioral economics impacted how economists discussed
rationality, from our own expertise on the matter, we observed that some
journals like the *Journal of Economic Behavior & Organization* or the
*Journal of Behavioral Economics*---later to be the *Journal of
Socio-Economics* and then the *Journal of Behavioral and Experimental
Economics*---were missing in places where they should be predominant.
This prompted us to further explore potential biases in JSTOR and to
augment our corpus with new full texts extracted from Elsevier and the
ISTEX project. Exploring raw sources is thus an important step that
requires to already engage with your material and the existing
literature.

The use of several databases also raised specific issues. Here, our goal
was to combine our textual data (from the three providers mentioned
above) with citation data from WoS. Achieving this required linking
documents across datasets, yet WoS---like many databases---does not
provide DOIs, which would otherwise serve as convenient unique
identifiers. It therefore fell to us to develop matching procedures to
determine whether an article retrieved from JSTOR or Scopus corresponded
to the same article indexed in WoS. However, matching based solely on
the title is unreliable. For example, the title *"Inflation and
Unemployment"* may refer either to James Tobin's
[-@tobinInflation1972] AEA presidential lecture or to Milton
Friedman's [-@friedman1977] Nobel lecture. Consequently, we had to
supplement title information with additional metadata, including the
journal name---which required standardizing journal titles across
databases---as well as the publication year, volume, issue, and page
range. Differences in journal coverage and in data storage practices
(particularly title formatting) mean that it is generally impossible to
achieve a complete match between databases. In our case, approximately
one-quarter of the full-text documents after 1945 could not be matched
to WoS records, which prevents us from analyzing their citation
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
[@edwardsFifty2020; @charlesRevue2025] or of one or several
individuals [@trucDisciplinary2025; @delceyDissemination2025] entails
comparatively definitional or boundary challenges. While some
large-scale studies focus on the discipline as a whole
[@claveauMacrodynamics2016; @trucInterdisciplinarityEconomics2023;
@ambrosinoWhat2018], such work still requires an operational
definition of what are documents in "economics." This definitional issue
becomes even more pronounced when the object of study is a specific
"field" (Cherrier, this issue) .

Non-quantitative historical methods tend to address large objects by
focusing on their "core" rather than their boundaries: historians of
economics typically reconstruct the history of materials that are
unambiguously part of the object under study, thus making a narrow
definition often unnecessary. Quantitative approaches, however, require
a well-defined corpus and consequently oblige researchers to impose
simple, clear-cut boundaries on complex and ambivalent categories such
as "economics". Defining the relevant historical materials therefore
requires the adoption of specific conventions to approximate the object
under study [@desrosieresPolitics2011]. Defining a corpus constitutes
a quantification convention---one that must always be assessed
instrumentally, not as an absolute definition but as an operational
hypothesis serving a specific research question.

Many proxies have been used in the history and philosophy of economics
to define disciplines and sub-disciplines. For instance,
[@goutsmedtIndependent2023] used the JEL codes to select macroeconomic
documents in a corpus of well-established economics journals, while
[@trucForty2022] and [@jullienHistory2024] relied respectively on
citations data and institutional affiliations to identify the boundaries
of behavioral economics. To choose a particular proxy, it is important
to understand how it relates to the object under study. Both JEL codes
and journal classifications---like JSTOR or Scopus classifications---can
structure a corpus in ways that reflect their own histories, and
researchers must therefore consider how these proxies shape the
boundaries of their material. For example, while the JEL codes for
neuroeconomics emerged around the same time as the first publications in
the field, the JEL codes for behavioral economics appeared more than two
decades after the earliest contributions [@trucNeuroeconomics2023]. A
thorough knowledge of the history of the object studied is thus crucial
for evaluating the adequacy and representativeness of the resulting
corpus.

In our case, we first define economic documents by building the corpus
from peer-review journals. This convention has both advantages and
limitations. On the one hand, this approach is unambiguous, as it relies
on agreeing upon a predefined list of journals, rather than, for
instance, determining at the document level which individual articles
qualify as economics. Moreover, journals constitute one of the main
legitimate institutional markers of a discipline, alongside training
programs and professional associations. On the other hand, focusing on
journals means excluding other publication outlets, such as books or
working papers.[^8] In addition, it struggles to capture
interdisciplinarity, whether in the form of interdisciplinary journals
or of economists publishing in other disciplinary journals. Finally,
this strategy requires the use of arbitrary criteria to decide which
journals to include and which to exclude---particularly for journals at
the margins of "economics", either because of their interdisciplinary
orientation or because of uncertainty regarding their peer-review
standards or academic practices. We eventually settled on a carefully
curated list of 329 journals identified as economics journals in JSTOR
and Scopus, but excluding journals that are not entirely academic,
insufficiently focused on economics, or only founded within the last
twenty years.[^9] We were able to retrieve 289538 articles published in
these journals from 1900 to 2009.

The second challenge was to restrain our corpus to documents engaging
with the issue of rationality. One of the most straightforward proxies
are keywords [@trucNeuroeconomics2023]. Based on a predefined list of
target terms (often called a "dictionary"), this approach restricts a
corpus to documents that mention these terms with at least a given
frequency. In addition to its relative simplicity, it works well for
specific and unambiguous terms, like "stagflation"
[@goutsmedtStagflation2021] or "Agent-Based Models"
[@bacciniDoes2025]. But this approach may display several limitations
when it is not the case. Indeed, it focuses on spotting occurrences of a
term rather than a general idea. Just think about the various ways
rationality could be discussed in the history of economics: beyond the
term "rationality", economists employ various expressions that refer to
close ideas such as maximising profits or expected utility, the *homo
oeconomicus*, or the transitivity and completeness of preferences.

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
documents---and in particular specific sentences within documents---that
deal with rationality in our corpus of economic articles.[^10] LLMs are
trained on extremely large collections of text to learn patterns in
language. In simple terms, they learn to predict missing words in a
sentence or to determine whether two sentences follow each other.
Through this training, the model develops billions of internal
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
of texts, but the overwhelming majority of these texts are recent.[^11]
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
comparing a sentence from, say, 1910 directly to a "representative
vector" of all sentences in our corpus that contain the words
"rationality" or "rational," we constructed a series of representative
vectors. For each year, we build a moving average vector, with a
five-year symmetric window, of all the sentences mentioning
"rationality" or "rational". Concretely, for the year 1910, we averaged
the vectors of all sentences containing "rationality" or "rational" from
1905 to 1915. This produces a period-specific reference point that
reflects how these terms were used at that particular moment in time. A
sentence from 1910 is therefore judged similar not to the general, and
likely modern-day meaning of rationality, but to the way the concept was
expressed during its own historical period. This helps ensure that our
analysis is sensitive to historical changes in language. Since each
document is a set of sentences, we also identify the documents---and the
authors---that discuss rationality most intensively or frequently.
@tbl-illustrative_sentences and @tbl-illustrative_documents illustrate
respectively the closest sentence and documents from our representative
vectors in 1910.

# **Exploring the corpus** 

# Simple exploration

Before returning to our specific corpus on rationality and diving into
more advanced LLM-based analyses, we first step back and examine simpler
quantitative methods applied to our broader set of economics articles.
Indeed, quantitative approaches come in many forms and levels of
complexity. In fact, quantification does not need to be sophisticated to
be useful. Simple indicators may not always provide the clearest answers
to research questions, but they can play an important exploratory role:
helping researchers refine their questions, identify anomalies, or
detect unexpected patterns.

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

@fig-relative-frequency shows the relative frequency (with respect to
the total number of words published each year) of "rational" and
"rationality" in our corpus. The figure reveals a steady postwar
increase of the use of both terms, likely reflecting the progressive
consolidation of rational choice theory in economics. We observe a
marked surge after the 1970s, with a pronounced peak for "rational" in
the 1980s, and a smaller peak for "rationality" in the 1990s. The rise
of "rational expectations" in macroeconomics and the emergence of
behavioral economics following the publication of @kahnemanProspect1979
likely contributed to this pattern. Of course, we cannot easily infer
the precise drivers of these trends from such simple metrics. However,
the clear upward movement signals an important moment in the evolution
of rationality within economics---at least in terms of textual
intensity---thereby motivating more targeted forms of investigation.

While our usage of a large language model will shed light on the context
surrounding this rise, such context can also be approximated with
simpler, more straightforward measures. Co-occurrence analysis helps
recover the different intellectual settings in which rationality is
invoked. @fig-co-occurence reports, by decade, the five words most
frequently adjacent to "rational" or "rationality," showing how these
associations shift over time. Before the 1930s, the picture was
heterogeneous. The notion was tied to the marginalist idea of
"calculation," but it referred not only to individual behavior but also
to "systems" or "organizations." The discussion was explicitly
methodological, as indicated by the prominence of terms such as
"method," "explanation," "law," and "foundation." From the 1940s onward,
the rise of choice theory places rationality at the center of economic
modeling as a device for describing and formalizing behavior. This is
mostly visible with the rise of multiple common bi-grams (i.e.,
combination of two words) that remain stable from the 1930s through the
1980s such as "economic rationality", "rational choice", "rational
behavior". By the 1970s---and especially the 1980s---the framework was
both extended and contested. First, the most common bi-gram by far
becomes "rational expectations" signalling the emergence of a new
predominant concept extending rationality. In the 1980s, "rational
expectations" appeared 15 more times than the other most common
bi-grams. Second, while the concept "bounded rationality" was developed
by Herbert Simon initially in the 1950s, the concept only became
prevalent during the 1990s with the bi-gram becoming the fourth most
common one.

Beyond textual data, citation data also constitute a useful source of
information for corpus exploration. The evolution of an idea depends not
only on how it is formulated by its authors, but also on how it is
appropriated, and reinterpreted by readers. A substantial literature in
citation theory examines how citations function as a scientific practice
and how they should be interpreted. As emphasized in this literature
[see, e.g., @TahamtanCore1979], citations may reflect a wide range of
motivations---from a genuine desire to acknowledge intellectual debt to
more strategic uses aimed at persuading readers or satisfying referees.
Nevertheless, citations at the very least signal a relationship that can
help trace the lineage and diffusion of ideas, even when the reasons
behind the citation are not purely intellectual.

Counting the citations of specific documents offers a first, simple
approach to assessing the impact of an author or a particular
publication. There are clear reasons to incorporate citation studies
into historical research. Beyond tracing diffusion, highly cited papers
tend to be more visible and attract greater engagement---a dynamic that
reflects the well-known Matthew effect [@mertonMatthew1968]. Recent
work also shows that citations influence reading behavior and
perceptions of quality: highly cited papers are more likely to be read
thoroughly and treated as significant intellectual contributions
[@teplitskiyHow2022].

Historians routinely discuss scientific influence and recognition using
proxies such as major grants, prizes, and honors. For example, Sent's
[-@sent_behavioral_2004] narrative of the transition from the
dominance of rational choice, through the limited success of "old"
behavioral economics (e.g., Simon, George Katona), to the emergence of
"new" behavioral economics is organized around such milestones. In this
sense, citations serve as a complementary proxy alongside these
traditional indicators. For instance, although both Simon and Kahneman
received the Nobel Prize, Kahneman ultimately exerted a broader
influence on the discipline---something that is reflected in citation
patterns. In a large qualitative--quantitative study of the Nobel Prize,
@offerNobel2016 distinguished several trajectories among laureates:
those who peak at the prize and subsequently decline, "innovators with
staying power," "still rising" winners honored before their citation
peak, and late winners recognized long after their peak.

@fig-rationality-paper-citations plots citation patterns across all WoS
economics journals and across the top five journals for four seminal
references that critiqued the standard approach to rationality in
economics. @simonBehavioral1955 and
@allaisComportementHommeRationnel1953 represent early critiques of
neoclassical rational choice, while @akerlofMarket1970 and
@kahnemanProspect1979 are foundational contributions to what economists
now refer to as "new" behavioral economics.

The influence of "new" behavioral economics clearly exceeds that of the
earlier tradition, both in the top five journals and in the broader set
of economics journals indexed in Web of Science. Whereas
@simonBehavioral1955 and @allaisComportementHommeRationnel1953 are
cited by no more than 0.2% of all economics articles,
@kahnemanProspect1979 surpasses 1% by the late 2010s and continues to
rise. The contrast lies not only in the scale of influence but also in
the speed and timing of acceptance: citations to the two "new"
behavioral papers grow rapidly and steadily from the moment of
publication, while Simon and Allais reach their modest peaks only around
the time of their Nobel Prizes---or even later in the 2000s, with the
renewed attention generated by "new" behavioral economics. As argued by
@offerNobel2016, many laureates experience a "Nobel premium," a modest
increase in citations following the award. Simon and Allais conform to
this pattern, but Kahneman and Tversky represent an exceptional case:
after the Nobel, their previously declining citation trajectory reverses
and climbs sharply throughout the period studied [@offerNobel2016].

## More advanced exploration

Citation counts are a blunt tool and cannot answer many questions of
interest to historians of economics: Who cites these works? Are they
cited together? In what intellectual contexts do they appear? Moreover,
focusing on a small set of references introduces a degree of
arbitrariness into the analysis. Likewise, simply counting the words
that appear next to "rationality" tells us little about whether these
words are used jointly within the same argument or whether they belong
to distinct topics and contexts that mobilize the concept differently.
It also overlooks the much broader vocabulary related to rationality
(e.g., profit maximization, expected utility, social choice).

Most recent quantitative studies in the history of economics rely on
what can be grouped under the label of "unsupervised methods." These
approaches apply algorithms to a corpus---whether full texts or citation
data---to generate classifications and assign categories that are not
predetermined by the researcher but that emerge from statistical
patterns in the data itself, which gives the approach its "unsupervised"
character.[^12] Assigning such categories imposes a form of internal
organization on large and otherwise unwieldy bodies of material,
enabling an accelerated or "distant reading" [@morettiDistant2013].
The typical output of these methods is a map of a discipline or research
area, showing how different entities---topics, articles,
authors---relate to one another.

The counterpart of unsupervised methods are supervised methods---such as
regressions---which estimate predefined relationships in the data. In
contrast, unsupervised methods are particularly well suited to
exploratory analysis. In this research context, analysts often lack
precise knowledge of the corpus and its various intellectual contexts.
While supervised methods require clearly specified hypotheses and
well-defined variables, unsupervised approaches allow researchers to let
a *chosen* structure of the material emerge. This is especially true for
large-scale and long-run analysis, where labelled data become harder to
obtain and increase the risk of imposing categories that are inadequate
or anachronistic relative to the historical context. That does not mean,
however, that an unsupervised algorithm can be applied blindly to
historical questions: a substantial part of our effort has consisted in
adapting the method to our historical data, especially to accommodate
the growth of the corpus over time.

In this paper, for citation data, we use a method commonly employed in
the history of economic thought: bibliographic coupling [ref]. We
begin with a corpus composed of the 10% of articles whose average
embeddings are most similar to our annual representative vectors for
"rationality" and "rational." In this network, articles are represented
as nodes, and connections between them depend on the number of shared
references in their bibliographies. The more references two articles
share, the stronger their link---and the closer they appear in a
two-dimensional network visualization. The underlying premise is that
shared references serve as a proxy for intellectual proximity. These
maps help delineate the boundaries of disciplines, fields, or
sub-specialties and reveal their internal organization, including
hierarchies and core--periphery structures.

However, citation practices tend to favor more recent works, which makes
it unhelpful for historians to construct a single citation network
spanning an entire century. Following a method that has proven effective
in the field [three papers], we therefore split our corpus into
overlapping eight-year windows, beginning in 1960 (1960--1967;
1961--1968; ... ; 2002--2009), and built a series of 43 separate
networks. Using community-detection algorithms [@traag...], we
identify groups of documents that share a substantial fraction of
references and therefore have a similar intellectual background; we
refer to these groups as "bibliographic communities." Our next step is
to identify communities that persist over time. When two communities
from consecutive networks share many of the same articles, we treat them
as instances of the same underlying group---an "intertemporal
bibliographic community." In this way, our bibliographic communities
bring together documents from different periods of time but that are
likely to engage with rationality in similar ways, based on their shared
citation patterns. This method allows us both to *zoom in* on specific
communities at a given period and to *zoom out* by reconstructing the
broader picture of a dynamic intellectual field.

For textual data, historians of economics frequently rely on topic
modeling [Ref]. Topic modeling identifies the latent themes in a
corpus by learning distributions of words associated with each topic.
Each document is then represented by a mixture of these topics---often
with one or two dominating---while each topic can be described through
its most representative words and expressions. While topic modeling is a
convenient tool for historical analysis, our research question pushed us
toward a more targeted approach.

Because we focus on one large and historically fluid concept, we draw on
the literature on semantic drift [ref] and take inspiration from
@ref. Rather than starting with full documents, we filter each year's
corpus to retain only the top 1% of sentences that are most similar to
our annual representative vectors of "rationality" and "rational." In
other words, we extract the sentences most likely to engage with the
concept of rationality in any form.[^13] As with bibliographic coupling,
we want a method that groups together sentences that employ similar
meanings of rationality. We therefore cluster the sentence embeddings
using the HDBSCAN algorithm, a widely used unsupervised method for
clustering LLM-generated vectors.

Again, historical perspective matters. Because the distribution of
identified sentences is strongly present-biased (@fig-distribution),
clustering all sentences at once would risk over-representing recent
periods. We therefore perform clustering separately for each decade from
1900 onward (merging the first two decades due to fewer sentences).[^14]
As in our bibliographic approach, we then seek to form larger groups
over time, allowing us to "zoom in" and "zoom out" depending on what we
are searching for. Using the cosine similarity between clusters across
decades, we merge the closest ones into 17 "intertemporal semantic
clusters."[^15]

With both methods, we thus obtain a list of "intertemporal bibliographic
communities" and "intertemporal semantic clusters." These allow us to
identify subgroups within our corpus across multiple dimensions:
different subfields of economics (e.g., behavioral economics,
macroeconomics), different conceptions of rationality (e.g., bounded
rationality, rational expectations), or even, more heuristically,
different methodological traditions (e.g., experimental work,
econometrics). Both approaches have clear strengths and limitations.
Some are largely inherited from their respective sources. In our case,
citation data cannot be meaningfully exploited before the 1960s, while
our OCR full texts handle formulas and tables poorly, making economic
models---an essential component of our story---less visible in the
semantic analysis than through citations. Choosing between the two
therefore depends directly on the specific historical questions one aims
to address.

Ideally, relying on *both* methods serves complementary purposes. First,
comparing the results of different unsupervised computational
approaches---such as LLM-based embeddings and bibliometric
analysis---acts as a form of robustness check.[^16] The systematic
comparison of sources and methods is a long-standing principle in
historical research, allowing scholars to triangulate information rather
than depend on a single perspective. Second, the two methods illuminate
different aspects of intellectual history. Full texts reveal the
meanings, contexts, and semantic nuances of rationality as economists
used the concept in their writing, independently of their institutional
proximity or citation habits. Citation data, by contrast, highlight
patterns of intellectual influence and diffusion: who cites whom, how
ideas travel across fields, and where intellectual boundaries lie. It
conveys sometimes a more sociological dimension: scholars tend to cite
the work of people publishing in similar journals, going to similar
conferences, etc. The following sub-section illustrates how we interpret
our results, and how the two methods complementarity may be useful.

## Interpreting "Results"

Taken together, the textual and bibliometric approaches allow us to
study both the semantic and thematic contexts of the uses of rationality
in economics and the channels through which these ideas circulated
within the discipline. But how should such a "study" proceed? Unlike
simpler quantitative tools, unsupervised methods do not produce
ready-made results. In our case, they generate statistical
categories---bibliographic communities and semantic clusters---that lack
predefined conceptual "labels". This strategy---reducing a large and
complex corpus to a smaller number of coherent groups---is well
established. Yet the groups themselves are created solely on the basis
of statistical similarities, and their historical or conceptual
significance emerges only through subsequent analysis. Groups resulting
from an unsupervised method can comprise, depending on the corpus,
anything from a few dozen to several thousand texts. To make sense of
what brings peculiar texts together, we therefore need indicators that
identify shared features and help hierarchise the documents to be read
first**.** At the same time, a good knowledge of the corpus and of the
relevant intellectual debates is indispensable for making sense of the
raw computational results, even once they have been informed by a set of
indicators.

Thus, whether at the stage of data construction or in the interpretation
of statistical patterns, quantitative methods demand a continuous
dialogue with qualitative interpretation, supported by a close reading
of the secondary literature on the topic at stake. Only through this
back-and-forth can we turn algorithmic groupings into meaningful
historical insights. This is both a weakness and a strength. On the one
hand, the analysis is not immediately transparent, as it requires the
construction of intermediate tools---such as our interactive
applications---to guide interpretation. On the other hand, it is
consistent with the practices of historians of economic thought, who
likewise select, prioritise, and read texts in order to make sense of
their corpus.

Let us take as an example the semantic cluster 11, which gathers close
to 20,000 sentences from 1920 to 2009. How can we get a sense of what
this cluster actually coalesces around? Before any qualitative
interpretation or contextualization with the secondary literature is
possible, we must first produce a series of indicators to characterize
the cluster. Such indicators include:

-   The most identifying words of the cluster for each decade. While the
    first period of the cluster (the 1920s) deals notably with
    "rationalisation" and "human reason," the 1950s are more directly
    focused on "rationalism," "rationality," and "rational behavior."
    After the 1970s and until 2009, "bounded rationality" emerges as a
    core concept in this cluster.

-   The most recurring authors. While Talcott Parsons and Frank Knight
    appear frequently in the 1920s and 1930s, Herbert Simon becomes a
    central author in the 1950s and 1970s. In the 1990s, we notably find
    Robert Sugden.

-   The journals that contain the most sentences associated with this
    cluster. The *Journal of Economic Issues*, oriented toward
    evolutionary economics, figures prominently, as do more
    behavioral-economics journals such as the *Journal of
    Socio-Economics* and the *Journal of Economic Behavior and
    Organization*.

-   The sentences within the semantic cluster that are closest to its
    year-representative vector, i.e., those closest to "rational" and
    "rationality," as well as the most representative sentences of the
    cluster for each period. The first category tends to highlight how
    the concept of rationality is discussed, while the second category
    centers more directly on the core semantic content of the cluster,
    often offering clues about the topics and debates that animate it in
    different periods. For instance, in the 1950s, one of the sentences
    closest to the representative vectors is Simon's claim that "If man,
    according to this interpretation, makes decisions and choices that
    have some appearance of rationality, rationality in real life must
    involve something simpler than maximization of utility or profit"
    [@simonTheories1959, 259--260]. As for the most representative
    sentences, Allan Drazen [@drazenRecent1980, 294] warned in the
    1980s that "Deciding on the suitable notion or definition of
    rationality is not an easy task," in his survey of the
    disequilibrium-theory literature in macroeconomics.

-   The articles with the most sentences in the cluster for each decade.
    Here we find, for example, Terence Hutchison's "Expectation and
    Rational Conduct" [@hutchisonExpectation1937]; Jacob Marschak's
    "Rational Behavior, Uncertain Prospects, and Measurable Utility"
    [@marschakRational1950]; Herbert Simon's 1978 Richard T. Ely
    Lecture at the AEA meetings [@simonRationality1978] and his Nobel
    lecture [@simonRational1979]; as well as Sugden's 1991 *Economic
    Journal* survey on rational choice [@sugdenRational1991].

-   For the periods after the 1950s, the most cited references (based on
    the number of citations per article, whether the article has one or
    ten sentences in the cluster). In the 1950s, for example, one of the
    most important references within this cluster is John von Neumann
    and Oskar Morgenstern's *Theory of Games and Economic Behavior*
    [@vonneumannTheory1944], while @kahnemanProspect1979 becomes the
    most cited reference in the 2000s.

With all these indicators---and prior to any further qualitative
investigation---we can already see that this semantic cluster is
centrally relevant to our study, as it bears directly on the concept of
rationality itself. Our textual approach is thus able to extract some
specific uses of rationality, here debates on the meaning of rationality
itself in economics, and to see the evolution of these uses across time
but also across topics and subdisciplines (in game theory,
macroeconomics, behavioral economics or evolutionary economics).

The bibliometric approach does not allow for such fine-grained temporal
or cross-subdisciplinary exploration. In our bibliometric communities,
no grouping addresses rationality and its limits in general across
multiple decades. Rather, bibliometric analysis identifies groups of
texts from authors in close academic communities. In relation to
semantic cluster 11, we observe, for instance, the emergence of a
"Behavioral Economics and Choice Theory" community in the 1977--1984
window. As with the semantic clusters, for each bibliometric community
in each temporal window we extract, notably, the sentences closest to
the representative vectors---based on the articles belonging to the
community---as well as the most cited references and the most
identifying words. We also examine how each community in a given window
originates (i.e., whether it derives primarily from the same or from
different communities in preceding periods) and what it becomes in the
following period (i.e., its subsequent "destiny").

# **Discussion**

Equipped with these groupings and series of indicators, we can begin to
make sense of our results. How can they help enrich, complete, and
refine our understanding of the various and evolving meanings of
rationality in economics? This paper does not propose an alternative
history of the concept, which would extend far beyond the scope of this
methodological discussion. Rather, we highlight selected findings that
corroborate and strengthen strands of the existing literature, notably
by allowing us to make claims about the prevalence and timing of
considerations about rationality, while also broadening the scope of
that literature and opening avenues for further research.

Throughout much of the period---but especially before the
1940s---sentences captured by our representative vectors refer sometimes
less to the rationality of economic agents than to the rational
character of economists' arguments, understood in terms of coherence or
sound reasoning. This pattern reflects the logic of our semantic
approach: LLMs tend to associate explicit mentions of rationality with
broader discussions of reasoning and coherence, even when the connection
to later, behavior-centered notions of rationality remains indirect. We
retain this ambivalence deliberately since it reveals both historical
transformation and the interpretative challenges inherent to large-scale
analysis.

Our goal is also to show how we navigate the results and triangulate the
indicators in order to produce coherent historical narratives. While we
rely on the secondary literature, the articles we foreground are only
those identified by our indicators as some of the most significant for
understanding the semantic clusters or bibliometric communities.[^17] We
provide two complementary discussions: a macro-level perspective that
highlights broad patterns in the evolution of rationality, and a
micro-level analysis that focuses on the emergence of a specific
topic---behavioral economics.

## Through the Telescope: Broad Patterns on the History of Rationality {#telescope}

When our quantitative inquiry begins in 1900, the concept of rationality
had already gained prominence, in line with the rise of scientific and
abstract reasoning in the late nineteenth century. The scope of rational
behavior was closely tied to debates on the proper domain of economic
analysis [@giocoliModeling2003].

With the marginalists, the economic agent was increasingly defined by
calculative capacity. Jevons, for instance, portrayed the agent as a
"calculating machine" balancing pleasures and pains, a view later
formalized as utility maximization [@maasMechanical1999].

In our first two decades, cluster 14 represents discussion centred on
utility and brings together insights on marginal utility from, among
others, Sidney. J. Chapman, Arthur Pigou, Francis Y. Edgeworth, and John
M. Clark. Cluster 4 also captures discussions about utility: economic
theory is debated through the history of economic thought. Arguments
about utility were framed as interpretations, critiques, or extensions
of classical authors---most notably Mill, Ricardo or Malthus. Yet, if
anything, marginal utility theory appears mostly under severe criticism
in this period, especially from institutionalist economists such as
Thorstein Veblen, Wesley Mitchell, John Maurice Clark, and Rexford
Tugwell.[^18]

The criticism was directed along two main lines. First, as
@giocoliModeling2003[48--50] points out, institutionalist economists
rejected the "unfounded psychological underpinnings of neoclassical
economics" and sought to replace them with sounder foundations [see
also @yonayStruggle2001, 101-106]. They proposed instead to renew the
economic method by drawing on psychology and its emerging "behaviorist"
approach [@rutherfordInstitutional2001, 175--176]. Semantic cluster
9---concerned throughout the period with general methodological issues
in economics---captures a significant share of sentences from 1900--1920
that articulate such institutionalist critiques. For instance,
@veblenLimitations1909[622--624] attacked the "marginal-utility
school" for relying on the simplistic depiction of human behavior
implied by the "hedonistic calculus." Institutionalists were energized
by new developments in psychology. In his review of the literature on
"Human Behavior and Economics," Mitchell emphasized the growing interest
of economists in psychological matters, which stemmed from "a somewhat
tardy recognition that hedonism is unsound psychology, and that the
economics of both Ricardo and Jevons originally rested on hedonistic
preconceptions" [@mitchellHuman1914, 1]. For economics, the crucial
issue was thus to choose "between providing a sounder psychological
basis for our analysis, and holding that its psychological basis does
not concern the economist" (2).[^19] Such criticism did not falter in
the 1920s. In cluster 11---centered at the time on rationalisation and
human reason---@tugwellHuman1922[317] encouraged economists to move
beyond the "rigid classical *homo economicus*" and noted that
"psychologists have already pretty well revolutionized the scientific
definition of human nature."

Second, for institutionalist economists, institutions were indispensable
for understanding economic behavior, and different institutions implied
different behaviors; there was no single, context-independent *homo
oeconomicus*. In cluster 9, @veblenLimitations1909[620] again argued
against the "statical character" of marginal-utility theory, which
offered "no theory of a movement of any kind," being occupied solely
with "the adjustment of values to a given situation." Similarly, E. H.
@downeyFutility1910[253], in the cluster 14, claimed that
"Marginal-utility economics has nothing to say of the genesis, growth,
or current working of economic institutions" [see also
@rutherfordInstitutionalist2013, 141]. Its "deliverances," he argued,
were therefore "futile for the problem of social betterment," since such
"betterment" concerned the adjustment of institutions to changing
circumstances and ideals. In the early twentieth century, economic
behavior, according to institutionalists, had to be understood through
the prism of the "pecuniary institutions" that shaped it. For instance,
Charles Cooley [@cooleyProgress1915] underlined that "pecuniary
valuation," or economic valuation, is only possible because of the
institutions that make such valuation possible [see also
@rutherfordInstitutionalist2013, 58--59]. Figure @fig-co-occurence
shows well the importance of "pecuniary" as a neighbor to "rational" and
"rationality" in the first twenty years of the twentieth century.

The centrality of institutionalist economists---as well as the
prominence of U.S. journals in our corpus---is visible in the scope of
the semantic clusters in the first periods: sentences related to
rationality, in addition to the clusters already mentioned, were grouped
into themes related to the railway industry (semantic cluster 8),
progressive taxation (cluster 17), tariffs and commercial policy in the
United States (cluster 8 again and part of cluster 2), or agriculture
(cluster 13). In line with institutionalism, most of these economists
examined these themes through the laws and rules governing economic
activity, focusing on how institutions structure the behaviour and
interests of collective actors rather than on abstract individual
assumptions. In these clusters, "rationality" is rarely mentioned
explicitly, even if we find discussions on the behavior of "business
men" (cluster 12), "workmen" (cluster 8) or "owners of land" and
"farmers" (cluster 13). These clusters gradually decline in importance,
and most of them disappear in the postwar period. Indeed, the period
from 1930 to 1959 displays substantial transformations in the structure
of debates concerning rationality.

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

While cluster 14 (on utility) constituted only a tiny share of sentences
between 1900 and 1919, and was absent in the 1920s, it gains importance
in the 1930s to the 1950s (though still representing less than 5% of all
sentences). During this period, the heart of the debate concerned the
measurability of utility and the opposition between "cardinal" and
"ordinal" utility. In the 1930s, the debate still bore on the
psychological dimension of utility measurement. In 1933, John Hicks and
Roy Allen [-@hicksReconsideration1934] coauthored an article on demand
analysis that eliminated marginal utility by appealing to the concept of
the marginal rate of substitution---the slope of the indifference curve
[see @moscatiMeasuring2019, 98--100]. Already in 1932, Allen had made
this project explicit: by starting from "preferential discrimination,"
or individuals' preferences over different bundles of goods, it becomes
unnecessary to "make any assumption about the existence of 'total
utility' or about the measurability of 'utility'; the hedonistic
hypothesis has been rendered superfluous" [@allenFoundations1932,
207]. In other words, "Subjective and psychological concepts have been
discarded from pure economic theory" (ibid.).

Yet this position was not uncontested. Indeed, in these debates, terms
such as "introspection," "satisfaction(s)," and "pleasure" recur
frequently in the cluster during the 1930s and 1940s [see for instance
@armstrongDeterminateness1939]. But they disappear from the top
identifying words in the 1950s. During this period, debates on ordinal
versus cardinal utility continued---with a renewed defense of the
cardinalist position and ongoing disputes about the very meaning of
"measuring utility" [@moscatiMeasuring2019, chapter 10]---yet these
discussions had largely emancipated themselves from psychological or
behaviorist considerations. These debates are also associated with a new
cluster (cluster 5), which appears in the 1940s and grows substantially
(to nearly 8% of all sentences) in the 1950s. This cluster concerns the
formalization of agents' preferences and choices. Here, we encounter
what would become the standard vocabulary of decision theory:
"individual orderings," "preferences," "decisions," "transitive," etc.,
and @vonneumannTheory1944, @friedmanUtility1948, and
@savageFoundations1954 appear as the most cited references in the core
articles of the cluster. To complete this panorama, a game-theory
cluster emerges in the 1950s, which ultimately comes to represent nearly
15% of all sentences after 1990.

Transformations in the conception of rationality are also visible
through clusters that remain thematically stable over time, yet reflect
profound shifts in the discipline's methodology and the growing
centrality of rational choice theory*.* Semantic cluster 12, for
instance, which spans the period from 1900 to 1979, deals with firms and
entrepreneurs. In the 1920s, the cluster emphasizes entrepreneurial
decision-making, understood primarily as prudence facing uncertainty
rather than formal optimization. From the 1940s, this cluster
increasingly centers on "profit maximization." The cluster captures the
core of the so-called "marginalist controversy"
[@backhouseFriedmans2009], notably through Richard Lester's attack on
marginal theory and Fritz Machlup's [-@machlupMarginal1946] response.
Machlup mounted a defense of profit maximization and, more broadly, of
marginalist theory. He rejected the evidential value of Lester's
questionnaire-based surveys of entrepreneurs, while Lester replied that
"at the heart of economic theory should be an adequate analysis and
understanding of the psychology, policies, and practices of business
management in modern industry" [@lesterMarginalism1947, 146].[^20] The
marginalist controversy more generally provided a key intellectual
background for Friedman's essay on positive economics
[-@friedmanMethodology1953], in which he formulated the famous "as if"
principle to justify, among other assumptions, profit maximization.
Interestingly, in the 1950s the most cited articles within cluster 12
were Machlup's [-@machlupMarginal1946] and Friedman's
[@friedmanUtility1948], both of which relied heavily on "as if"
reasoning, notably to justify the assumption of expected utility.

Shifts in the discipline's methodology are also captured by semantic
cluster 9, which gathers sentences in which authors reflect on their own
methodological choices*.* While in the 1920s and 1930s economists still
engaged with notions such as "human nature," "passions," or
"prejudices," the postwar period saw the growing prominence of terms
such as "logical implications" and "assumptions," followed, from the
1970s onward, by an increasing focus on "models" and "optimality."

It thus becomes clear that by the 1950s the conception of rationality
had been profoundly transformed, moving in a more formal direction and
largely emancipated from psychology. Another transformation also
deserves emphasis: as rationality was recast in terms of consistent
choice rather than as a psychological portrait of *homo oeconomicus*,
the normative dimension expanded---from individual behavior to questions
of social choice and to the design of "rationalizing" policies
[@herfeldTheories2018; @handsNormative2015].

The emergence of this social dimension of rationality is already
observable in the interwar period. In the 1930s, cluster 11 focused on
the concept---relatively neglected in the history of economic
thought---of "rationalization." In a literature review on this concept,
Robert Brady [@bradyMeaning1932, 526] remarked that "scarcely any
term... has occasioned more discussion and dispute." The concept
referred to "every technique, program, or plan of organization which
promised to promote (...) the 'efficiency' of individual enterprises,
entire industries, or even the total of economic processes nationally or
internationally considered." Attention to "rationalisation" is also
visible in cluster 13, devoted to agricultural economics and the rise of
"farm management" aimed at improving farmers' living conditions. It
becomes even more pronounced with the multiplication of debates on
economic planning and the rationalization of policy decisions from the
1940s onward, particularly in cluster 8.

As rationality increasingly came to be framed through modern
microeconomics, the concept was extended to both individual and
collective choice. In semantic cluster 5---gathering sentences on
decision theory---the rational "decision making" is not applied not only
for individuals but also for firms and public policy. It is also in this
cluster that issues of social choice emerge, notably debates on the
implications of Arrow's impossibility theorem [-@arrowSocial1951; see
e.g. @igersheimDeath2019].[^21] Arrow's contribution also stimulated
the formation of cluster 16 on law and economics in the 1960s, where it
appears as the primary reference, alongside works by @downsEconomic1957
and @buchananCalculus1962. This cluster is closely associated with
publications by *Public Choice* [see @cherrierEconomists2017].
Welfare economics and public choice, as well as public finance
[@desmarais-tremblayPublic2023], are also clearly visible in the
bibliometric analysis after 1960. Indeed, one of the major bibliometric
communities of the 1960s is organized around public goods and
externalities, with James Buchanan, Ronald Coase, and Richard Musgrave
as central references. The prominence of public finance increases
further in subsequent decades, with the appearance of another community
devoted to optimal taxation after 1968; taken together, these two
communities account for nearly one fifth of the entire network in this
period.

We have seen how the meaning of rationality progressively transformed
and formalized after the 1930s, and how the rationalization of
collective decision-making became central in the postwar period. So far,
however, we have said little about macroeconomics. Macroeconomics
constituted a relatively important semantic cluster from the beginning
of our period, in 1900, notably through monetary economics (cluster 1).
This cluster grew in importance in the 1930s, particularly in connection
with debates surrounding Keynes's work, liquidity preference, and
unemployment. It is only in the 1970s, however, that this cluster
becomes dominant in our panorama of rationality. This shift is closely
linked to the emergence of the concept of "rational expectations," which
profoundly transformed the way rationality was discussed in economics.
The concept was developed by @muthRational1961 but only later
popularized when Carnegie colleagues---Robert E. Lucas, Edward C.
Prescott, and Thomas J. Sargent---applied it to macroeconomics
[@lucasExpectations1972; @sargentRational1973]. By the late 1970s, it
had circulated beyond academia into policy circles and the press and was
often described as a "rational expectations revolution"
[@duarteRise2025]. Our methods help account for this rapid diffusion
beyond controversial policy debates during the stagflation era. First,
the results show no significant trace of rational expectations in the
1960s in either the bibliometric or textual outputs.[^22] But from the
1970s onward, it occupies a central place in the literature on
rationality, reaching its apogee in the 1980s, when it accounted for
nearly 30% of all sentences in the textual analysis, as well as a
comparable share of articles in the bibliometric analysis, spread across
several bibliometric communities ("Rational Expectations and Business
Cycles," "Exchange Rate Economics," and "Inflation, Expectations, and
Interest Rates").

A similar trajectory to macroeconomics can also be observed in finance.
The origins of financial issues can be traced to semantic cluster 3
which focused initially on the theory of investment. Until the 1930s,
the issue was framed around the returns of capital. For instance, the
cluster includes the so-called Hayek-Knight controversy on the
conception of capital [@CohenHayek2003]. After the 1940s,
decision-making under uncertainty becomes a central theme, crystallized
by works such as @shackleTheory1942 on investment under radical
uncertainty, which figures among the most representative articles. One
decade later, Jack @hirshleiferInvestment1958 inscribed investment
theory within the rising neoclassical conception of rationality, by
formalizing investment decisions as a problem of intertemporal
maximization of consumption*.* In the same vein, the Modigliani--Miller
theorem [@ModiglianiCost1958] further consolidated this shift by
grounding firm financial decisions as an arbitrage problem, opening the
path to modern financial economics. Their theorem, they argued, can be
used "as a basis for rational investment decision-making within the
firm" [@ModiglianiCost1958: 296]. After the 1960s, cluster 3 became
much more prominent, consistently accounting for more than 10% of all
sentences. In this period, rationality is increasingly framed in formal
decision-theoretic terms and focused on appropriate investment choices
under uncertainty. Hence, our analysis shows that rationality in finance
enters primarily through corporate finance, rather than through
asset-pricing issues such as market efficiency, where rationality long
remains an implicit assumption and rarely discussed explicitly prior to
the emergence of behavioral finance.

From the 1980s onward, modern asset pricing becomes dominant within
cluster 3 as indicated by the growing prominence of terms such as
"assets," "arbitrage," and "capital asset pricing". We also observe
increasing proximities between the finance literature and the
rational-expectations framework from the mid-1970s onward. This is both
visible in the semantic clusters and in the bibliometric communities, in
particular, the "Rational Expectations and Market Information," which
emerges in the 1976--1983 window. A central contribution found in both
semantic and bibliometric clusters is @grossmanImpossibility1980, which
draws on Lucas's imperfect-information framework
[@lucasExpectations1972] and combines rational expectations with noisy
signals to question market efficiency. More generally, rational
expectations models---initially developed in a macroeconomic
context---became a central framework for analyzing the (ir)rational use
of information in finance [see @delceyEfficient2023].

The 1970s and 1980s thus marked a relative dominance of macroeconomics
and finance, with comparatively less weight given to debates on
individual rationality. This situation begins to change gradually from
the 1980s onward. In the 1979--1986 bibliometric network, a "Behavioral
Decision Theory" community appears (representing around 2% of the
network), capturing the early emergence of behavioral economics as
promoted by Kahneman and Tversky. In the 1990s, the rise of behavioral
economics---together with new approaches in game theory---fundamentally
altered this configuration, leading to more specialized investigations
of individual rationality, which now dominate and are distributed across
multiple bibliometric communities. This transformation represents not
merely a shift in research topics, but a profound reframing of how
economics approaches rationality: from an assumption embedded in
theories and models to an object of direct investigation at the
individual level.

We have sought here to offer a broad panorama of the major
transformations in the concept of "rationality" in economics. This
approach allows us to identify large-scale changes when they become
visible in the data---namely, when particular clusters come to represent
a significant share of sentences (or of the bibliometric networks).
However, historians of economic thought are often concerned with
understanding how such transformations came about: which contributions,
authors, and communities played a decisive role. Addressing these
questions requires a more focused perspective, tracing the evolution of
specific topics and literatures. This is the aim of the next section,
which moves beyond the panoramic view to provide a more detailed
narrative of the rise of behavioral economics outlined above.

## Under the Microscope: Simon's Reception and the Birth of Behavioural Economics

The term \"behavioral economics\" has a complex history. While nowadays
it is mostly associated to Kahneman and Tversky, George Katona is often
credited as an early adopter [@giladEconomic1984;
@hosseiniGeorge2011]. To distinguish different strands of behavioral
economics, @sent_behavioral_2004 made an historical distinction between
"old" and "new" behavioral economics to separates the "old" heterogenous
attempts by Katona, Simon and others to reform mainstream economics from
the "new" more homogenous heuristic and biases research program of
Kahneman and Tversky. Sent argues that \"new\" behavioral economics
succeeded it was less radical than "old" approaches, and that it emerged
in the 1980s when economic theory faced multiple epistemological
challenges, creating an opportune moment for alternative approaches.

The divergent fates of Herbert Simon\'s bounded rationality and Daniel
Kahneman and Amos Tversky\'s heuristics and biases approache present a
striking puzzle in the history of economic thought. Both challenged
standard rationality assumptions under a "behavioral economics"
approach, both earned Nobel recognition, yet their reception patterns
differed dramatically. While our method cannot pinpoint the exact
epistemological reasons for this shift, we can trace the patterns of
reception and influence of both approaches to understand how and when
they diverged.

Our analysis suggests that Simon\'s concept of \"bounded rationality\"
do stands as one of the most influential critiques of standard
rationality in economics in the sense that it framed a lot of the
debates surrounding rationality. His presence dominated 1960s and 1970s
discussions with his seminal articles and Nobel lecture
[@simonRational1979] appearing across numerous research areas from
social choice theory to the theory of the firm and price setting. The
textual analysis demonstrates Simon\'s conceptual centrality: Cluster
11, which captures discussions of individual rationality in economics,
transformed rapidly after Simon\'s influence rose in the 1970s. In the
1950s, the general discourse of economists centered on terms like
\"rational,\" \"empirical reality,\" and \"irrationality.\" By the
1970s, \"bounded rationality\" had become the cluster\'s most prevalent
expression, and by the 1990s, discussions of \"boundedly rational
agents\" and \"procedural rationality\" clearly positioned Simon\'s
concepts as central to economic thought with a late but significant
integration.

Not only did economists\' language about rationality change radically
after Simon\'s ideas gained traction, but these discussions also became
substantially more prevalent. Cluster 11\'s share of all sentences grew
from 5.76% in the 1950s to 7.85% in the 1980s, peaking at 9.56% in the
1990s. This represents a major shift in how much attention economics
devoted to foundational questions about rationality. Citation analysis
corroborates this late integration: references to @simonBehavioral1955
rose slowly after publication, with peak citations occurring only in the
post-2000s period (@fig-rationality-paper-citations).

However, Simon\'s influence remained limited in two critical respects.
First, the slow adoption of his framework meant that by the time it
achieved conceptual prominence, it faced competition from \"new\"
behavioral economics. After peaking in the 1990s, Cluster 11 declined to
7.43% of sentences in the early 2000s. While bounded rationality
remained conceptually embedded in many parts of economics, a larger
transformation was underway. Progressively after the 1980s, Cluster
11\'s relative importance decreased in favor of more specialized
clusters, each addressing specific dimensions of rationality: Clusters 5
and 15 examined expected utility theory, risk, and ambiguity; Clusters 6
and 7 focused on intertemporal and other-regarding behavior. All these
clusters grew increasingly important in the 1980s, with most of them
individually surpassing Cluster 11 in sentence share. While they
integrated bounded rationality ideas, they did so primarily through
\"new\" behavioral economics concepts, from prospect theory for risk, to
experimental paradigms like the ultimatum game for other-regarding
behavior [@gualaParadigmatic2008].

Second, Simon\'s conceptual influence, spearheaded by bounded
rationality, never translated into stable research communities. While
his framework shaped how many economists approached rationality, very
few actually developed the research program he initiated.
Bibliometrically, only small, unstable clusters formed around Simon\'s
work. In the 1960s and early 1970s, his ideas appeared in operations
research circles (*Firm Behavior and Planning*) and organizational
theory critiques of profit maximization (*Organizational Efficiency and
Firm Theory*). Simon was generally associated with other researchers
critical of perfect rationality: @winterSatisficing1971, which applied
satisficing to firm behavior; @cyertCompetition1969 on behavioral
theory of the firm; and @leibensteinAllocative1966 on \"X-efficiency,\"
challenging economics\' focus on allocative efficiency. Together, Simon,
Winter, Cyert, and Leibenstein formed a diverse organizational theory
critique of how rationality, especially through profit maximization, is
employed in economics. While this collective movement had some momentum,
none of these research had an individual effect on economics structure.
After 1969--1976, this research stream coalesced into a smaller,
short-lived community before fragmenting. References to Simon and
critiques of profit maximization remained scattered, moving through
several small communities (e.g., cl_761, cl_251, *Welfare Economics and
Public Finance*, *Evolutionary Economic Theory*) without ever achieving
the critical mass. While Simon\'s influence in economics was
conceptually enduring, it remained marginal as a structuring force,
unable to generate coherent, large and stable research communities.

Studying "new" behavioral economics reception reveals a dramatic
contrast. In the 1979--1987 period, most clusters citing Simon became
absorbed into a large \"Behavioral Decision Theory\" cluster dominated
by Kahneman and Tversky. Unlike Simon\'s trajectory, the heuristics and
biases research program of Kahneman, Tversky, and other \"new\"
behavioral economists generated multiple stable clusters that formed
well-identified and substantial research communities. A main
\"Behavioral Decision Theory\" cluster emerged in the 1980s, structured
by early adopters of the new approach. The crystallization of this
distinct cluster signaled the beginning of explosive growth and the
spinning off of several autonomous communities that captured emerging
specialized areas of behavioral economics: pro-social behavior and
behavioral game theory (*Behavioral Game Theory*), intertemporal
decision-making and risk (*Behavioral Economics and Choice*), and
behavioral finance (*Financial Market Expectations*).

By the 2000s, behavioral economics had become the dominant venue for
research on rationality. Three behavioral economics clusters represented
approximately 30% of the entire network with many additional clusters
structured by behavioral economics research without being explicitly
characterized as such. The scale and speed of acceptance differed
dramatically from Simon\'s experience. By 1980, @kahnemanProspect1979
was already more cited than @simonBehavioral1955 had been at that point
(@fig-rationality-paper-citations). By 1985, prospect theory had
surpassed the lifetime citation peak that Simon\'s work would ever
achieve in economics. By the 2000s, most microeconomics publications
about rationality connected to the behavioral economics research
program. While bounded and procedural rationality remained regularly
invoked concepts, no later research community clearly carried Simon\'s
heritage as a bibliometric anchor.

The contrast is stark and raises fundamental questions about
disciplinary reception: Why did one Nobel Prize-winning critique of
rationality spawn a research empire while another remained conceptually
influential but institutionally homeless?

Our quantitative study yields two particularly surprising results about
the contrasting reception of Kahneman and Simon. First, the temporal
pattern of adoption differed radically. For historian
@heukelomBehavioral2014, a pivotal moment in behavioral economics
history was the explicit creation of research programs within the Sloan
and Russell Sage Foundations between 1984 and 1992, notably leading to
the Kahneman-Thaler collaboration that transformed the field\'s
trajectory. However, our analysis suggests that even by the early 1980s,
something distinctive was already happening with Kahneman and Tversky\'s
reception. Despite @kahnemanProspect1979 being the duo\'s only
economics publication until 1985 --- long before the Sloan-Sage
Foundation programs formalized behavioral economics --- prospect theory
became highly cited with rapid growth
(@fig-rationality-paper-citations). As early as the 1977--1984
bibliometric network, we find a cluster structured by their work,
suggesting that their article not only attracted citations but rapidly
catalyzed new research strands in a way Simon\'s work never achieved in
economics [@heukelomSense2012].

This rapid adoption is particularly striking given the external
similarities between the cases. Both Kahneman and Simon published in top
economics journals and received Nobel Prizes. Yet Simon\'s Nobel Prize
increased his influence in economics only marginally, while Kahneman\'s
Nobel reversed a downward citation trend in the 2000s, cementing their
contribution as a structural pillar of a wide-spanning research program.

The second surprising finding concerns the relationship between \"old\"
and \"new\" behavioral economics. Citations to @simonBehavioral1955
have never been higher than since the ascent of new behavioral
economics, a paradoxical pattern given accusations that the field has
forgotten its roots. @earlPrinciples2022 criticizes this apparent
amnesia:

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
    [@earlPrinciples2022, 2]

The rising citations to older work from Simon and Allais demonstrate
that while \"new\" behavioral economists may not always acknowledge
\"old\" behavioral economics contributions all the time, the field\'s
rapid growth and large size has actually drawn more attention to earlier
work than it ever received during its original publication period. This
pattern admits at least three interpretations, each with different
implications for how we understand the evolution of economic thought.

A favorable reading suggests that the \"new\" behavioral economics
genuinely helped revive abandoned research directions, moving toward
reconciliation with earlier strands, a research direction wished by
@sentRationality2008 and more recently by @earlPrinciples2022. A more
critical view sees intellectual appropriation, in which classic
references are strategically reframed to fit the new agenda, renewing
interest but through a biased and presentist lens as it happened with
Allais [@monginAllais2019]. A third interpretation suggests that
citation increases reflect growing backlash against the \"new\" program
from defenders of \"old\" behavioral economics, as critics invoke Simon
and others to challenge the heuristics and biases framework.

Our findings tentatively support the second interpretation. The sparse
and unstructured citation patterns to \"old\" behavioral economics,
combined with the fact that discussions of rationality are increasingly
framed by \"new\" behavioral and experimental concepts, suggest
appropriation rather than genuine integration. Citations may acknowledge
earlier work without meaningfully engaging its methodological or
theoretical distinctiveness. The conceptual influence of Simon remains
as a way to frame the general discussion and reconstruct behavioral
economics intellectual lineages, but his actual methodological and
conceptual framework remain superficially integrated. While a definitive
conclusion requires deeper qualitative analysis of how these citations
are used in contemporary work, our study provides a quantitative roadmap
for future research examining the complex relationship between \"old\"
and \"new\" behavioral economics.

# **Conclusion**

This article is first and foremost methodological: it aims to
demonstrate, through a concrete application, the usefulness of
quantitative methods for the history of economic thought. Nonetheless,
it does so by breaking new ground in the history and philosophy of
economics. First, the corpus we build---comprising nearly 290,000
full-text economics articles spanning more than a century---is, to our
knowledge, the largest and most comprehensive database ever used to
study economic contributions in English. Second, this article
constitutes the first application of quantitative methods to the study
of semantic change within the history of economics, an area that
represents an important and growing strand of the broader literature on
quantitative text analysis [@peritiSystematic2024].

Our approach allows us to identify, within this corpus, the sentences
most closely associated with the words "rational" and "rationality" and,
by extension, the articles most likely to engage with rationality in one
way or another. This procedure necessarily involves setting similarity
thresholds to determine when a sentence or an article can be considered
sufficiently "close." By retaining approximately 500,000 sentences for
the textual analysis and 29,000 articles for the bibliometric analysis,
we deliberately opted for a broad initial corpus. Higher thresholds
would have reduced these numbers and restricted the material to
discussions more narrowly centered on rationality. Our methodological
choice was instead to cast a wide net at the outset, in order to
preserve flexibility for subsequent stages of analysis.

This choice is central to the interest of the unsupervised methods we
deploy. By allowing the algorithms to identify dozens of semantic
clusters and bibliometric communities within short temporal windows
(eight years or a decade), and by then aggregating these groupings over
time and characterizing them through multiple indicators, we can conduct
analyses at different scales. This makes it possible both to *zoom out*,
by examining the overall configuration of clusters across periods, and
to *zoom in*, by focusing on subsets of clusters more directly concerned
with rationality. As shown in the previous section, a panoramic view
that considers all semantic clusters may initially include groups that
appear only loosely connected to rationality---especially in the early
decades. While examining these clusters can be informative for
understanding the broader intellectual context, the analyst can also
foreground more explicitly rationality-oriented clusters when addressing
more targeted research questions. This flexibility is only possible
because the initial corpus is sufficiently inclusive, reducing the risk
of overlooking relevant developments. More generally, our approach
allows the scale of analysis to be adjusted to the question at hand,
rather than imposing it ex ante.

We want to conclude by drawing several general methodological and
historiographic claims from the approaches developed in this article.

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
making available two interactive applications to explore our results, we
hope to encourage readers to pursue their own paths of discovery within
the corpus.

[^1]: The bibliometric communities, identified through network analysis,
    could also be called clusters. But we opted for "communities" in
    order to distinguish them from the "semantic clusters".

[^2]: To be clear, we don't think that quantitative methods are only
    helpful for very large corpora. However, it is where their surplus
    value may appear as the most obvious.

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

[^8]: Adding these other outlets would pose additional challenges. For
    both working papers and, above all, books, no large-scale databases
    provide comprehensive full texts or complete reference lists. In
    addition, working papers raise the problem of potential double
    counting, as they may eventually be published in economic journals.

[^9]: We did not filter journals by language a priori. Indeed, many
    non-anglo-saxon journals also publish English articles at some more
    or less frequent occasions. It was thus easier to filter by language
    a posteriori and at the document level, once articles were
    collected.

[^10]: Our goal here is not to provide the reader with extensive details
    on what these models are and how we use them (see the appendix for
    additional details and references), but rather to provide general
    intuitions about the use of the LLMs, to understand the building of
    our corpus.

[^11]: Moreover, the texts used to train these models are not primarily
    academic articles in economics. This means that there may be
    important gaps between the general language patterns the model has
    learned and the specific vocabulary, concepts, and writing practices
    of our "domain" [see e.g. @zhangEconBERT2025].

[^12]: "Unsupervised" does not mean that the modeller has no influence
    on the output. The analysts must choose a particular model and its
    parameters and these choices embed methodological priors about the
    types of patterns the procedure is likely to reveal. For instance,
    one famous crucial parameter in many unsupervised models is the
    number of categories that will emerge from the algorithm.

[^13]: Taking the top 1% means that we consider, once excluded as much
    as we can, bibliographies, headings, etc, that 1 sentence over 100
    in economics articles deal with rationality. This threshold is, of
    course, open to discussion and can easily be adjusted.

[^14]: Note here that we don't use overlapping windows in this case,
    notably for computational reasons: finding HDSBCAN clusters on a set
    of tens of thousands of sentences is much computationally intensive
    than finding bibliographic communities for at most five thousands of
    articles..

[^15]: Refer to the appendix for more details about this.

[^16]: Modeling choices (for example, the minimum size of clusters in
    the HDBSCAN algorithm) affect the partition in communities and
    clusters. Since these outputs are never self-interpreting and always
    require human qualitative assessment, it is time consuming to
    conduct robustness checks.

[^17]: Of course, as in any historical inquiry of this kind, we are not
    entirely protected from selective emphasis and from choosing
    illustrations that support a particular line of interpretation---all
    the more so given that the scope of our study is too broad to
    summarize every pattern revealed by our results. Other scholars
    could have, at various junctures, pursued different interpretive
    directions on the basis of the same material. The publication of the
    interactive applications we used to explore the results thus serves
    as an exercise in transparency and---in addition to being, we hope,
    useful for historians of economic thought more generally---allows
    readers to assess the robustness and limits of our narrative.

[^18]: However, because we focus on English, published articles, our
    clusters are likely biased toward American journals, notably in the
    first decades.

[^19]: Some years earlier, @mitchellRationality1910[97; see semantic
    cluster 9 and 4] already pushed forward similar claims, regretting
    that "few economists have regarded the study of psychology as a
    necessary part of the equipment of their work", often relying on
    "tacit preconceptions" rather than to seek to "psychologists to gain
    a knowledge of the mind and its modes of operation".

[^20]: Machlup's position was that even if a "goodly portion of all
    business behavior may be non-rational, thoughtless, [or] blindly
    repetitive" [-@machlupMarginal1946, 520], questionnaire evidence
    and empirical findings more generally did not demonstrate the
    failure of marginal theory when properly interpreted. In a similar
    defense of profit maximization, Leonid @hurwiczTheory1946[110]
    first acknowledged that it was not "inconceivable that business is
    run more by routine than by rationality", but argued that behavior
    may appear irrational or merely "routine" from the standpoint of a
    purely static theory that ignores uncertainty, while proving fully
    "rational" once uncertainty and long-run effects are taken into
    account [see also @herfeldTheories2018].

[^21]: This grouping of sentences in the 1970s actually took its origins
    in the semantic cluster 14 on utility, which ended in the 1960s,
    with a focus on welfare economics.

[^22]: This highlights a key caveat. Because these methods foreground
    statistically "significant" patterns and indicators' prevalence,
    they are not always well suited to tracing and interpreting the
    origins of a concept or theory with the care that close historical
    study and archival research provide.
