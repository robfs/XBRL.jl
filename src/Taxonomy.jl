module Taxonomy

using Memoize, LRUCache

include("uri_helper.jl")

using ..EzXML, ..Cache, ..Linkbases, ..Exceptions

import HTTP: unescapeuri

export Concept, TaxonomySchema, ExtendedLinkRole
export parsetaxonomy, parsecommontaxonomy, parsetaxonomy_url, gettaxonomy, gettaxonomylut!

const NAME_SPACES = [
    "xsd" => "http://www.w3.org/2001/XMLSchema",
    "link" => "http://www.xbrl.org/2003/linkbase",
    "xlink" => "http://www.w3.org/1999/xlink",
    "xbrldt" => "http://xbrl.org/2005/xbrldt",
]

const NS_SCHEMA_MAP = Dict([
    "http://arelle.org/doc/2014-01-31" => "http://arelle.org/2014/doc-2014-01-31.xsd",
    "http://fasb.org/dis/cecltmp01/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-cecltmp01-2019-01-31.xsd",
    "http://fasb.org/dis/cecltmp02/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-cecltmp02-2019-01-31.xsd",
    "http://fasb.org/dis/cecltmp03/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-cecltmp03-2019-01-31.xsd",
    "http://fasb.org/dis/cecltmp04/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-cecltmp04-2019-01-31.xsd",
    "http://fasb.org/dis/cecltmp05/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-cecltmp05-2019-01-31.xsd",
    "http://fasb.org/dis/fifvdtmp01/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-fifvdtmp01-2018-01-31.xsd",
    "http://fasb.org/dis/fifvdtmp01/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-fifvdtmp01-2019-01-31.xsd",
    "http://fasb.org/dis/fifvdtmp02/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-fifvdtmp02-2018-01-31.xsd",
    "http://fasb.org/dis/fifvdtmp02/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-fifvdtmp02-2019-01-31.xsd",
    "http://fasb.org/dis/idestmp011/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-idestmp011-2018-01-31.xsd",
    "http://fasb.org/dis/idestmp011/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-idestmp011-2019-01-31.xsd",
    "http://fasb.org/dis/idestmp012/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-idestmp012-2018-01-31.xsd",
    "http://fasb.org/dis/idestmp012/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-idestmp012-2019-01-31.xsd",
    "http://fasb.org/dis/idestmp021/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-idestmp021-2018-01-31.xsd",
    "http://fasb.org/dis/idestmp021/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-idestmp021-2019-01-31.xsd",
    "http://fasb.org/dis/idestmp022/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-idestmp022-2018-01-31.xsd",
    "http://fasb.org/dis/idestmp022/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-idestmp022-2019-01-31.xsd",
    "http://fasb.org/dis/idestmp03/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-idestmp03-2018-01-31.xsd",
    "http://fasb.org/dis/idestmp03/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-idestmp03-2019-01-31.xsd",
    "http://fasb.org/dis/idestmp04/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-idestmp04-2018-01-31.xsd",
    "http://fasb.org/dis/idestmp04/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-idestmp04-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp01/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp01-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp021/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp021-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp022/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp022-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp023/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp023-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp024/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp024-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp025/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp025-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp031/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp031-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp032/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp032-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp033/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp033-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp041/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp041-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp042/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp042-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp051/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp051-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp052/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp052-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp061/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp061-2019-01-31.xsd",
    "http://fasb.org/dis/insldtmp062/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-insldtmp062-2019-01-31.xsd",
    "http://fasb.org/dis/leasestmp01/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-leasestmp01-2017-01-31.xsd",
    "http://fasb.org/dis/leasestmp02/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-leasestmp02-2017-01-31.xsd",
    "http://fasb.org/dis/leasestmp03/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-leasestmp03-2017-01-31.xsd",
    "http://fasb.org/dis/leasestmp04/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-leasestmp04-2017-01-31.xsd",
    "http://fasb.org/dis/leasestmp05/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-leasestmp05-2017-01-31.xsd",
    "http://fasb.org/dis/leastmp01/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-leastmp01-2018-01-31.xsd",
    "http://fasb.org/dis/leastmp01/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-leastmp01-2019-01-31.xsd",
    "http://fasb.org/dis/leastmp02/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-leastmp02-2018-01-31.xsd",
    "http://fasb.org/dis/leastmp02/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-leastmp02-2019-01-31.xsd",
    "http://fasb.org/dis/leastmp03/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-leastmp03-2018-01-31.xsd",
    "http://fasb.org/dis/leastmp03/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-leastmp03-2019-01-31.xsd",
    "http://fasb.org/dis/leastmp04/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-leastmp04-2018-01-31.xsd",
    "http://fasb.org/dis/leastmp04/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-leastmp04-2019-01-31.xsd",
    "http://fasb.org/dis/leastmp05/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-leastmp05-2018-01-31.xsd",
    "http://fasb.org/dis/leastmp05/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-leastmp05-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp011/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp011-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp011/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp011-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp011/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp011-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp012/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp012-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp012/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp012-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp012/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp012-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp02/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp02-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp02/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp02-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp02/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp02-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp03/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp03-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp03/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp03-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp03/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp03-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp04/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp04-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp04/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp04-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp04/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp04-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp041/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp041-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp041/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp041-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp041/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp041-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp05/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp05-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp05/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp05-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp05/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp05-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp06/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp06-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp06/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp06-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp06/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp06-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp07/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp07-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp07/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp07-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp07/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp07-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp08/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp08-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp08/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp08-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp08/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp08-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp09/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp09-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp09/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp09-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp09/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp09-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp102/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp102-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp102/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp102-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp102/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp102-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp103/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp103-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp103/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp103-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp103/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp103-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp104/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp104-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp104/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp104-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp104/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp104-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp105/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp105-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp105/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp105-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp105/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp105-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp111/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp111-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp111/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp111-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp111/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp111-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp112/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp112-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp112/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp112-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp112/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp112-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp121/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp121-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp121/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp121-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp121/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp121-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp122/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp122-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp122/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp122-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp122/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp122-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp123/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp123-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp123/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp123-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp123/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp123-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp125/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp125-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp125/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp125-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp125/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp125-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp131/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp131-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp131/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp131-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp131/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp131-2019-01-31.xsd",
    "http://fasb.org/dis/rbtmp141/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rbtmp141-2017-01-31.xsd",
    "http://fasb.org/dis/rbtmp141/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rbtmp141-2018-01-31.xsd",
    "http://fasb.org/dis/rbtmp141/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rbtmp141-2019-01-31.xsd",
    "http://fasb.org/dis/rcctmp01/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rcctmp01-2017-01-31.xsd",
    "http://fasb.org/dis/rcctmp01/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rcctmp01-2018-01-31.xsd",
    "http://fasb.org/dis/rcctmp01/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rcctmp01-2019-01-31.xsd",
    "http://fasb.org/dis/rcctmp03/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rcctmp03-2017-01-31.xsd",
    "http://fasb.org/dis/rcctmp03/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rcctmp03-2018-01-31.xsd",
    "http://fasb.org/dis/rcctmp03/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rcctmp03-2019-01-31.xsd",
    "http://fasb.org/dis/rcctmp04/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rcctmp04-2017-01-31.xsd",
    "http://fasb.org/dis/rcctmp04/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rcctmp04-2018-01-31.xsd",
    "http://fasb.org/dis/rcctmp04/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rcctmp04-2019-01-31.xsd",
    "http://fasb.org/dis/rcctmp05/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/dis/us-gaap-dis-rcctmp05-2017-01-31.xsd",
    "http://fasb.org/dis/rcctmp05/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/dis/us-gaap-dis-rcctmp05-2018-01-31.xsd",
    "http://fasb.org/dis/rcctmp05/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/dis/us-gaap-dis-rcctmp05-2019-01-31.xsd",
    "http://fasb.org/srt/2018-01-31" => "http://xbrl.fasb.org/srt/2018/elts/srt-2018-01-31.xsd",
    "http://fasb.org/srt/2019-01-31" => "http://xbrl.fasb.org/srt/2019/elts/srt-2019-01-31.xsd",
    "http://fasb.org/srt/2020-01-31" => "http://xbrl.fasb.org/srt/2020/elts/srt-2020-01-31.xsd",
    "http://fasb.org/srt/2021-01-31" => "http://xbrl.fasb.org/srt/2021/elts/srt-2021-01-31.xsd",
    "http://fasb.org/srt-roles/2018-01-31" => "http://xbrl.fasb.org/srt/2018/elts/srt-roles-2018-01-31.xsd",
    "http://fasb.org/srt-roles/2019-01-31" => "http://xbrl.fasb.org/srt/2019/elts/srt-roles-2019-01-31.xsd",
    "http://fasb.org/srt-roles/2020-01-31" => "http://xbrl.fasb.org/srt/2020/elts/srt-roles-2020-01-31.xsd",
    "http://fasb.org/srt-roles/2021-01-31" => "http://xbrl.fasb.org/srt/2021/elts/srt-roles-2021-01-31.xsd",
    "http://fasb.org/srt-types/2018-01-31" => "http://xbrl.fasb.org/srt/2018/elts/srt-types-2018-01-31.xsd",
    "http://fasb.org/srt-types/2019-01-31" => "http://xbrl.fasb.org/srt/2019/elts/srt-types-2019-01-31.xsd",
    "http://fasb.org/srt-types/2020-01-31" => "http://xbrl.fasb.org/srt/2020/elts/srt-types-2020-01-31.xsd",
    "http://fasb.org/srt-types/2021-01-31" => "http://xbrl.fasb.org/srt/2021/elts/srt-types-2021-01-31.xsd",
    "http://fasb.org/us-gaap/2011-01-31" => "http://xbrl.fasb.org/us-gaap/2011/elts/us-gaap-2011-01-31.xsd",
    "http://fasb.org/us-gaap/2012-01-31" => "http://xbrl.fasb.org/us-gaap/2012/elts/us-gaap-2012-01-31.xsd",
    "http://fasb.org/us-gaap/2013-01-31" => "http://xbrl.fasb.org/us-gaap/2013/elts/us-gaap-2013-01-31.xsd",
    "http://fasb.org/us-gaap/2014-01-31" => "http://xbrl.fasb.org/us-gaap/2014/elts/us-gaap-2014-01-31.xsd",
    "http://fasb.org/us-gaap/2015-01-31" => "http://xbrl.fasb.org/us-gaap/2015/elts/us-gaap-2015-01-31.xsd",
    "http://fasb.org/us-gaap/2016-01-31" => "http://xbrl.fasb.org/us-gaap/2016/elts/us-gaap-2016-01-31.xsd",
    "http://fasb.org/us-gaap/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/elts/us-gaap-2017-01-31.xsd",
    "http://fasb.org/us-gaap/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/elts/us-gaap-2018-01-31.xsd",
    "http://fasb.org/us-gaap/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/elts/us-gaap-2019-01-31.xsd",
    "http://fasb.org/us-gaap/2020-01-31" => "http://xbrl.fasb.org/us-gaap/2020/elts/us-gaap-2020-01-31.xsd",
    "http://fasb.org/us-gaap/2021-01-31" => "http://xbrl.fasb.org/us-gaap/2021/elts/us-gaap-2021-01-31.xsd",
    "http://fasb.org/us-roles/2011-01-31" => "http://xbrl.fasb.org/us-gaap/2011/elts/us-roles-2011-01-31.xsd",
    "http://fasb.org/us-roles/2012-01-31" => "http://xbrl.fasb.org/us-gaap/2012/elts/us-roles-2012-01-31.xsd",
    "http://fasb.org/us-roles/2013-01-31" => "http://xbrl.fasb.org/us-gaap/2013/elts/us-roles-2013-01-31.xsd",
    "http://fasb.org/us-roles/2014-01-31" => "http://xbrl.fasb.org/us-gaap/2014/elts/us-roles-2014-01-31.xsd",
    "http://fasb.org/us-roles/2015-01-31" => "http://xbrl.fasb.org/us-gaap/2015/elts/us-roles-2015-01-31.xsd",
    "http://fasb.org/us-roles/2016-01-31" => "http://xbrl.fasb.org/us-gaap/2016/elts/us-roles-2016-01-31.xsd",
    "http://fasb.org/us-roles/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/elts/us-roles-2017-01-31.xsd",
    "http://fasb.org/us-roles/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/elts/us-roles-2018-01-31.xsd",
    "http://fasb.org/us-roles/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2019/elts/us-roles-2019-01-31.xsd",
    "http://fasb.org/us-roles/2020-01-31" => "http://xbrl.fasb.org/us-gaap/2020/elts/us-roles-2020-01-31.xsd",
    "http://fasb.org/us-roles/2021-01-31" => "http://xbrl.fasb.org/us-gaap/2021/elts/us-roles-2021-01-31.xsd",
    "http://fasb.org/us-types/2011-01-31" => "http://xbrl.fasb.org/us-gaap/2011/elts/us-types-2011-01-31.xsd",
    "http://fasb.org/us-types/2012-01-31" => "http://xbrl.fasb.org/us-gaap/2012/elts/us-types-2012-01-31.xsd",
    "http://fasb.org/us-types/2013-01-31" => "http://xbrl.fasb.org/us-gaap/2013/elts/us-types-2013-01-31.xsd",
    "http://fasb.org/us-types/2014-01-31" => "http://xbrl.fasb.org/us-gaap/2014/elts/us-types-2014-01-31.xsd",
    "http://fasb.org/us-types/2015-01-31" => "http://xbrl.fasb.org/us-gaap/2015/elts/us-types-2015-01-31.xsd",
    "http://fasb.org/us-types/2016-01-31" => "http://xbrl.fasb.org/us-gaap/2016/elts/us-types-2016-01-31.xsd",
    "http://fasb.org/us-types/2017-01-31" => "http://xbrl.fasb.org/us-gaap/2017/elts/us-types-2017-01-31.xsd",
    "http://fasb.org/us-types/2018-01-31" => "http://xbrl.fasb.org/us-gaap/2018/elts/us-types-2018-01-31.xsd",
    "http://fasb.org/us-types/2019-01-31" => "http://xbrl.fasb.org/us-gaap/2020/elts/us-types-2020-01-31.xsd",
    "http://fasb.org/us-types/2021-01-31" => "http://xbrl.fasb.org/us-gaap/2021/elts/us-types-2021-01-31.xsd",
    "http://ici.org/rr/2006" => "http://xbrl.ici.org/rr/2006/ici-rr.xsd",
    "http://www.esma.europa.eu/xbrl/esef/arcrole/wider-narrower" => "http://www.xbrl.org/lrr/arcrole/esma-arcrole-2018-11-21.xsd",
    "http://www.w3.org/1999/xlink" => "http://www.xbrl.org/2003/xlink-2003-12-31.xsd",
    "http://www.xbrl.org/2003/instance" => "http://www.xbrl.org/2003/xbrl-instance-2003-12-31.xsd",
    "http://www.xbrl.org/2003/linkbase" => "http://www.xbrl.org/2003/xbrl-linkbase-2003-12-31.xsd",
    "http://www.xbrl.org/2003/XLink" => "http://www.xbrl.org/2003/xl-2003-12-31.xsd",
    "http://www.xbrl.org/2004/ref" => "http://www.xbrl.org/2004/ref-2004-08-10.xsd",
    "http://www.xbrl.org/2006/ref" => "http://www.xbrl.org/2006/ref-2006-02-27.xsd",
    "http://www.xbrl.org/2009/arcrole/deprecated" => "http://www.xbrl.org/lrr/arcrole/deprecated-2009-12-16.xsd",
    "http://www.xbrl.org/2009/arcrole/fact-explanatoryFact" => "http://www.xbrl.org/lrr/arcrole/factExplanatory-2009-12-16.xsd",
    "http://www.xbrl.org/2009/role/deprecated" => "http://www.xbrl.org/lrr/role/deprecated-2009-12-16.xsd",
    "http://www.xbrl.org/2009/role/negated" => "http://www.xbrl.org/lrr/role/negated-2009-12-16.xsd",
    "http://www.xbrl.org/2009/role/net" => "http://www.xbrl.org/lrr/role/net-2009-12-16.xsd",
    "http://www.xbrl.org/dtr/type/2020-01-21" => "http://www.xbrl.org/dtr/type/2020-01-21/types.xsd",
    "http://www.xbrl.org/dtr/type/non-numeric" => "http://www.xbrl.org/dtr/type/nonNumeric-2009-12-20.xsd",
    "http://www.xbrl.org/dtr/type/numeric" => "http://www.xbrl.org/dtr/type/numeric-2009-12-16.xsd",
    "http://www.xbrl.org/us/fr/common/fste/2005-02-28" => "http://www.xbrl.org/us/fr/common/fste/2005-02-28/usfr-fste-2005-02-28.xsd",
    "http://www.xbrl.org/us/fr/common/fstr/2005-02-28" => "http://www.xbrl.org/us/fr/common/fstr/2005-02-28/usfr-fstr-2005-02-28.xsd",
    "http://www.xbrl.org/us/fr/common/ime/2005-06-28" => "http://www.xbrl.org/us/fr/common/ime/2005-06-28/usfr-ime-2005-06-28.xsd",
    "http://www.xbrl.org/us/fr/common/pte/2005-02-28" => "http://www.xbrl.org/us/fr/common/pte/2005-02-28/usfr-pte-2005-02-28.xsd",
    "http://www.xbrl.org/us/fr/common/ptr/2005-02-28" => "http://www.xbrl.org/us/fr/common/ptr/2005-02-28/usfr-ptr-2005-02-28.xsd",
    "http://www.xbrl.org/us/fr/gaap/basi/2005-02-28" => "http://www.xbrl.org/us/fr/gaap/basi/2005-02-28/us-gaap-basi-2005-02-28.xsd",
    "http://www.xbrl.org/us/fr/gaap/ci/2005-02-28" => "http://www.xbrl.org/us/fr/gaap/ci/2005-02-28/us-gaap-ci-2005-02-28.xsd",
    "http://www.xbrl.org/us/fr/gaap/im/2005-06-28" => "http://www.xbrl.org/us/fr/gaap/im/2005-06-28/us-gaap-im-2005-06-28.xsd",
    "http://www.xbrl.org/us/fr/gaap/ins/2005-02-28" => "http://www.xbrl.org/us/fr/gaap/ins/2005-02-28/us-gaap-ins-2005-02-28.xsd",
    "http://www.xbrl.org/us/fr/rpt/ar/2005-02-28" => "http://www.xbrl.org/us/fr/rpt/ar/2005-02-28/usfr-ar-2005-02-28.xsd",
    "http://www.xbrl.org/us/fr/rpt/mda/2005-02-28" => "http://www.xbrl.org/us/fr/rpt/mda/2005-02-28/usfr-mda-2005-02-28.xsd",
    "http://www.xbrl.org/us/fr/rpt/mr/2005-02-28" => "http://www.xbrl.org/us/fr/rpt/mr/2005-02-28/usfr-mr-2005-02-28.xsd",
    "http://www.xbrl.org/us/fr/rpt/seccert/2005-02-28" => "http://www.xbrl.org/us/fr/rpt/seccert/2005-02-28/usfr-seccert-2005-02-28.xsd",
    "http://xbrl.ifrs.org/taxonomy/2013-09-09/ifrs" => "http://xbrl.ifrs.org/taxonomy/2013-09-09/ifrs-cor_2013-09-09.xsd",
    "http://xbrl.ifrs.org/taxonomy/2014-03-05/ifrs-full" => "http://xbrl.ifrs.org/taxonomy/2014-03-05/full_ifrs/full_ifrs-cor_2014-03-05.xsd",
    "http://xbrl.ifrs.org/taxonomy/2014-03-05/ifrs-smes" => "http://xbrl.ifrs.org/taxonomy/2014-03-05/ifrs_for_smes/ifrs_for_smes-cor_2014-03-05.xsd",
    "http://xbrl.ifrs.org/taxonomy/2015-03-11/ifrs-full" => "http://xbrl.ifrs.org/taxonomy/2015-03-11/full_ifrs/full_ifrs-cor_2015-03-11.xsd",
    "http://xbrl.ifrs.org/taxonomy/2016-03-31/ifrs-full" => "http://xbrl.ifrs.org/taxonomy/2016-03-31/full_ifrs/full_ifrs-cor_2016-03-31.xsd",
    "http://xbrl.ifrs.org/taxonomy/2017-03-09/ifrs-full" => "http://xbrl.ifrs.org/taxonomy/2017-03-09/full_ifrs/full_ifrs-cor_2017-03-09.xsd",
    "http://xbrl.ifrs.org/taxonomy/2018-03-16/ifrs-full" => "http://xbrl.ifrs.org/taxonomy/2018-03-16/full_ifrs/full_ifrs-cor_2018-03-16.xsd",
    "http://xbrl.ifrs.org/taxonomy/2019-03-27/ifrs-full" => "http://xbrl.ifrs.org/taxonomy/2019-03-27/full_ifrs/full_ifrs-cor_2019-03-27.xsd",
    "http://xbrl.ifrs.org/taxonomy/2020-03-16/ifrs-full" => "http://xbrl.ifrs.org/taxonomy/2020-03-16/full_ifrs/full_ifrs-cor_2020-03-16.xsd",
    "http://xbrl.org/2005/xbrldt" => "http://www.xbrl.org/2005/xbrldt-2005.xsd",
    "http://xbrl.org/2006/xbrldi" => "http://www.xbrl.org/2006/xbrldi-2006.xsd",
    "http://xbrl.org/2020/extensible-enumerations-2.0" => "http://www.xbrl.org/2020/extensible-enumerations-2.0.xsd",
    "http://xbrl.sec.gov/country/2011-01-31" => "https://xbrl.sec.gov/country/2011/country-2011-01-31.xsd",
    "http://xbrl.sec.gov/country/2012-01-31" => "https://xbrl.sec.gov/country/2012/country-2012-01-31.xsd",
    "http://xbrl.sec.gov/country/2013-01-31" => "https://xbrl.sec.gov/country/2013/country-2013-01-31.xsd",
    "http://xbrl.sec.gov/country/2016-01-31" => "https://xbrl.sec.gov/country/2016/country-2016-01-31.xsd",
    "http://xbrl.sec.gov/country/2017-01-31" => "https://xbrl.sec.gov/country/2017/country-2017-01-31.xsd",
    "http://xbrl.sec.gov/country/2020-01-31" => "https://xbrl.sec.gov/country/2020/country-2020-01-31.xsd",
    "http://xbrl.sec.gov/country/2021" => "https://xbrl.sec.gov/country/2021/country-2021.xsd",
    "http://xbrl.sec.gov/currency/2011-01-31" => "https://xbrl.sec.gov/currency/2011/currency-2011-01-31.xsd",
    "http://xbrl.sec.gov/currency/2012-01-31" => "https://xbrl.sec.gov/currency/2012/currency-2012-01-31.xsd",
    "http://xbrl.sec.gov/currency/2014-01-31" => "https://xbrl.sec.gov/currency/2014/currency-2014-01-31.xsd",
    "http://xbrl.sec.gov/currency/2016-01-31" => "https://xbrl.sec.gov/currency/2016/currency-2016-01-31.xsd",
    "http://xbrl.sec.gov/currency/2017-01-31" => "https://xbrl.sec.gov/currency/2017/currency-2017-01-31.xsd",
    "http://xbrl.sec.gov/currency/2019-01-31" => "https://xbrl.sec.gov/currency/2019/currency-2019-01-31.xsd",
    "http://xbrl.sec.gov/currency/2020-01-31" => "https://xbrl.sec.gov/currency/2020/currency-2020-01-31.xsd",
    "http://xbrl.sec.gov/currency/2021" => "https://xbrl.sec.gov/currency/2021/currency-2021.xsd",
    "http://xbrl.sec.gov/dei/2011-01-31" => "https://xbrl.sec.gov/dei/2011/dei-2011-01-31.xsd",
    "http://xbrl.sec.gov/dei/2012-01-31" => "https://xbrl.sec.gov/dei/2012/dei-2012-01-31.xsd",
    "http://xbrl.sec.gov/dei/2013-01-31" => "https://xbrl.sec.gov/dei/2013/dei-2013-01-31.xsd",
    "http://xbrl.sec.gov/dei/2014-01-31" => "https://xbrl.sec.gov/dei/2014/dei-2014-01-31.xsd",
    "http://xbrl.sec.gov/dei/2018-01-31" => "https://xbrl.sec.gov/dei/2018/dei-2018-01-31.xsd",
    "http://xbrl.sec.gov/dei/2019-01-31" => "https://xbrl.sec.gov/dei/2019/dei-2019-01-31.xsd",
    "http://xbrl.sec.gov/dei/2020-01-31" => "https://xbrl.sec.gov/dei/2020/dei-2020-01-31.xsd",
    "http://xbrl.sec.gov/dei/2021" => "https://xbrl.sec.gov/dei/2021/dei-2021.xsd",
    "http://xbrl.sec.gov/dei-def/2021" => "https://xbrl.sec.gov/dei/2021/dei-2021_def.xsd",
    "http://xbrl.sec.gov/dei-entire/2021" => "https://xbrl.sec.gov/dei/2021/dei-entire-2021.xsd",
    "http://xbrl.sec.gov/dei-ent-std/2019-01-31" => "https://xbrl.sec.gov/dei/2019/dei-ent-std-2019-01-31.xsd",
    "http://xbrl.sec.gov/dei-ent-std/2020-01-31" => "https://xbrl.sec.gov/dei/2020/dei-ent-std-2020-01-31.xsd",
    "http://xbrl.sec.gov/dei-lab/2021" => "https://xbrl.sec.gov/dei/2021/dei-2021_lab.xsd",
    "http://xbrl.sec.gov/dei-pre/2021" => "https://xbrl.sec.gov/dei/2021/dei-2021_pre.xsd",
    "http://xbrl.sec.gov/dei-std/2019-01-31" => "https://xbrl.sec.gov/dei/2019/dei-std-2019-01-31.xsd",
    "http://xbrl.sec.gov/dei-std/2020-01-31" => "https://xbrl.sec.gov/dei/2020/dei-std-2020-01-31.xsd",
    "http://xbrl.sec.gov/exch/2011-01-31" => "https://xbrl.sec.gov/exch/2011/exch-2011-01-31.xsd",
    "http://xbrl.sec.gov/exch/2012-01-31" => "https://xbrl.sec.gov/exch/2012/exch-2012-01-31.xsd",
    "http://xbrl.sec.gov/exch/2013-01-31" => "https://xbrl.sec.gov/exch/2013/exch-2013-01-31.xsd",
    "http://xbrl.sec.gov/exch/2014-01-31" => "https://xbrl.sec.gov/exch/2014/exch-2014-01-31.xsd",
    "http://xbrl.sec.gov/exch/2015-01-31" => "https://xbrl.sec.gov/exch/2015/exch-2015-01-31.xsd",
    "http://xbrl.sec.gov/exch/2016-01-31" => "https://xbrl.sec.gov/exch/2016/exch-2016-01-31.xsd",
    "http://xbrl.sec.gov/exch/2017-01-31" => "https://xbrl.sec.gov/exch/2017/exch-2017-01-31.xsd",
    "http://xbrl.sec.gov/exch/2018-01-31" => "https://xbrl.sec.gov/exch/2018/exch-2018-01-31.xsd",
    "http://xbrl.sec.gov/exch/2019-01-31" => "https://xbrl.sec.gov/exch/2019/exch-2019-01-31.xsd",
    "http://xbrl.sec.gov/exch/2020-01-31" => "https://xbrl.sec.gov/exch/2020/exch-2020-01-31.xsd",
    "http://xbrl.sec.gov/exch/2021" => "https://xbrl.sec.gov/exch/2021/exch-2021.xsd",
    "http://xbrl.sec.gov/exch-def/2021" => "https://xbrl.sec.gov/exch/2021/exch-2021_def.xsd",
    "http://xbrl.sec.gov/exch-lab/2021" => "https://xbrl.sec.gov/exch/2021/exch-2021_lab.xsd",
    "http://xbrl.sec.gov/exch-pre/2021" => "https://xbrl.sec.gov/exch/2021/exch-2021_pre.xsd",
    "http://xbrl.sec.gov/invest/2011-01-31" => "https://xbrl.sec.gov/invest/2011/invest-2011-01-31.xsd",
    "http://xbrl.sec.gov/invest/2012-01-31" => "https://xbrl.sec.gov/invest/2012/invest-2012-01-31.xsd",
    "http://xbrl.sec.gov/invest/2013-01-31" => "https://xbrl.sec.gov/invest/2013/invest-2013-01-31.xsd",
    "http://xbrl.sec.gov/naics/2011-01-31" => "https://xbrl.sec.gov/naics/2011/naics-2011-01-31.xsd",
    "http://xbrl.sec.gov/naics/2017-01-31" => "https://xbrl.sec.gov/naics/2017/naics-2017-01-31.xsd",
    "http://xbrl.sec.gov/naics/2021" => "https://xbrl.sec.gov/naics/2021/naics-2021.xsd",
    "http://xbrl.sec.gov/rr/2010-02-28" => "https://xbrl.sec.gov/rr/2010/rr-2010-02-28.xsd",
    "http://xbrl.sec.gov/rr/2012-01-31" => "https://xbrl.sec.gov/rr/2012/rr-2012-01-31.xsd",
    "http://xbrl.sec.gov/rr/2018-01-31" => "https://xbrl.sec.gov/rr/2018/rr-2018-01-31.xsd",
    "http://xbrl.sec.gov/rr/2021" => "https://xbrl.sec.gov/rr/2021/rr-2021.xsd",
    "http://xbrl.sec.gov/rr-cal/2010-02-28" => "https://xbrl.sec.gov/rr/2010/rr-cal-2010-02-28.xsd",
    "http://xbrl.sec.gov/rr-cal/2012-01-31" => "https://xbrl.sec.gov/rr/2012/rr-cal-2012-01-31.xsd",
    "http://xbrl.sec.gov/rr-cal/2018-01-31" => "https://xbrl.sec.gov/rr/2018/rr-cal-2018-01-31.xsd",
    "http://xbrl.sec.gov/rr-def/2010-02-28" => "https://xbrl.sec.gov/rr/2010/rr-def-2010-02-28.xsd",
    "http://xbrl.sec.gov/rr-def/2012-01-31" => "https://xbrl.sec.gov/rr/2012/rr-def-2012-01-31.xsd",
    "http://xbrl.sec.gov/rr-def/2018-01-31" => "https://xbrl.sec.gov/rr/2018/rr-def-2018-01-31.xsd",
    "http://xbrl.sec.gov/rr-def/2021" => "https://xbrl.sec.gov/rr/2021/rr-2021_def.xsd",
    "http://xbrl.sec.gov/rr-ent/2010-02-28" => "https://xbrl.sec.gov/rr/2010/rr-ent-2010-02-28.xsd",
    "http://xbrl.sec.gov/rr-ent/2012-01-31" => "https://xbrl.sec.gov/rr/2012/rr-ent-2012-01-31.xsd",
    "http://xbrl.sec.gov/rr-ent/2018-01-31" => "https://xbrl.sec.gov/rr/2018/rr-ent-2018-01-31.xsd",
    "http://xbrl.sec.gov/rr-lab/2021" => "https://xbrl.sec.gov/rr/2021/rr-2021_lab.xsd",
    "http://xbrl.sec.gov/rr-pre/2010-02-28" => "https://xbrl.sec.gov/rr/2010/rr-pre-2010-02-28.xsd",
    "http://xbrl.sec.gov/rr-pre/2012-01-31" => "https://xbrl.sec.gov/rr/2012/rr-pre-2012-01-31.xsd",
    "http://xbrl.sec.gov/rr-pre/2018-01-31" => "https://xbrl.sec.gov/rr/2018/rr-pre-2018-01-31.xsd",
    "http://xbrl.sec.gov/rr-pre/2021" => "https://xbrl.sec.gov/rr/2021/rr-2021_pre.xsd",
    "http://xbrl.sec.gov/sic/2011-01-31" => "https://xbrl.sec.gov/sic/2011/sic-2011-01-31.xsd",
    "http://xbrl.sec.gov/sic/2020-01-31" => "https://xbrl.sec.gov/sic/2020/sic-2020-01-31.xsd",
    "http://xbrl.sec.gov/sic/2021" => "https://xbrl.sec.gov/sic/2021/sic-2021.xsd",
    "http://xbrl.sec.gov/stpr/2011-01-31" => "https://xbrl.sec.gov/stpr/2011/stpr-2011-01-31.xsd",
    "http://xbrl.sec.gov/stpr/2018-01-31" => "https://xbrl.sec.gov/stpr/2018/stpr-2018-01-31.xsd",
    "http://xbrl.sec.gov/stpr/2021" => "https://xbrl.sec.gov/stpr/2021/stpr-2021.xsd", # Replace draft taxonomy with official STPR 2021 one once it is released
    "http://xbrl.us/ar/2008-03-31" => "http://xbrl.us/us-gaap/1.0/non-gaap/ar-2008-03-31.xsd",
    "http://xbrl.us/ar/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/non-gaap/ar-2009-01-31.xsd",
    "http://xbrl.us/country/2008-03-31" => "http://xbrl.us/us-gaap/1.0/non-gaap/country-2008-03-31.xsd",
    "http://xbrl.us/country/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/non-gaap/country-2009-01-31.xsd",
    "http://xbrl.us/currency/2008-03-31" => "http://xbrl.us/us-gaap/1.0/non-gaap/currency-2008-03-31.xsd",
    "http://xbrl.us/currency/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/non-gaap/currency-2009-01-31.xsd",
    "http://xbrl.us/dei/2008-03-31" => "http://xbrl.us/us-gaap/1.0/non-gaap/dei-2008-03-31.xsd",
    "http://xbrl.us/dei/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/non-gaap/dei-2009-01-31.xsd",
    "http://xbrl.us/dei-ent/2008-03-31" => "http://xbrl.us/us-gaap/1.0/non-gaap/dei-ent-2008-03-31.xsd",
    "http://xbrl.us/dei-std/2008-03-31" => "http://xbrl.us/us-gaap/1.0/non-gaap/dei-std-2008-03-31.xsd",
    "http://xbrl.us/dei-std/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/non-gaap/dei-std-2009-01-31.xsd",
    "http://xbrl.us/exch/2008-03-31" => "http://xbrl.us/us-gaap/1.0/non-gaap/exch-2008-03-31.xsd",
    "http://xbrl.us/exch/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/non-gaap/exch-2009-01-31.xsd",
    "http://xbrl.us/invest/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/non-gaap/invest-2009-01-31.xsd",
    "http://xbrl.us/mda/2008-03-31" => "http://xbrl.us/us-gaap/1.0/non-gaap/mda-2008-03-31.xsd",
    "http://xbrl.us/mda/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/non-gaap/mda-2009-01-31.xsd",
    "http://xbrl.us/mr/2008-03-31" => "http://xbrl.us/us-gaap/1.0/non-gaap/mr-2008-03-31.xsd",
    "http://xbrl.us/mr/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/non-gaap/mr-2009-01-31.xsd",
    "http://xbrl.us/naics/2008-03-31" => "http://xbrl.us/us-gaap/1.0/non-gaap/naics-2008-03-31.xsd",
    "http://xbrl.us/naics/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/non-gaap/naics-2009-01-31.xsd",
    "http://xbrl.us/rr/2008-12-31" => "http://taxonomies.xbrl.us/rr/2008/rr-2008-12-31.xsd",
    "http://xbrl.us/rr-ent/2008-12-31" => "http://taxonomies.xbrl.us/rr/2008/rr-ent-2008-12-31.xsd",
    "http://xbrl.us/rr-std/2008-12-31" => "http://taxonomies.xbrl.us/rr/2008/rr-std-2008-12-31.xsd",
    "http://xbrl.us/seccert/2008-03-31" => "http://xbrl.us/us-gaap/1.0/non-gaap/seccert-2008-03-31.xsd",
    "http://xbrl.us/seccert/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/non-gaap/seccert-2009-01-31.xsd",
    "http://xbrl.us/sic/2008-03-31" => "http://xbrl.us/us-gaap/1.0/non-gaap/sic-2008-03-31.xsd",
    "http://xbrl.us/sic/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/non-gaap/sic-2009-01-31.xsd",
    "http://xbrl.us/soi/2008-11-30" => "http://taxonomies.xbrl.us/soi/2008/soi-2008-11-30.xsd",
    "http://xbrl.us/stpr/2008-03-31" => "http://xbrl.us/us-gaap/1.0/non-gaap/stpr-2008-03-31.xsd",
    "http://xbrl.us/stpr/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/non-gaap/stpr-2009-01-31.xsd",
    "http://xbrl.us/us-gaap/2008-03-31" => "http://xbrl.us/us-gaap/1.0/elts/us-gaap-2008-03-31.xsd",
    "http://xbrl.us/us-gaap/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/elts/us-gaap-2009-01-31.xsd",
    "http://xbrl.us/us-gaap/negated/2008-03-31" => "http://www.xbrl.org/lrr/role/negated-2008-03-31.xsd",
    "http://xbrl.us/us-roles/2008-03-31" => "http://xbrl.us/us-gaap/1.0/elts/us-roles-2008-03-31.xsd",
    "http://xbrl.us/us-roles/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/elts/us-roles-2009-01-31.xsd",
    "http://xbrl.us/us-types/2008-03-31" => "http://xbrl.us/us-gaap/1.0/elts/us-types-2008-03-31.xsd",
    "http://xbrl.us/us-types/2009-01-31" => "http://taxonomies.xbrl.us/us-gaap/2009/elts/us-types-2009-01-31.xsd",
])

mutable struct Concept
    xml_id::String
    schema_url::Union{String,Nothing}
    name::String
    type::Union{String,Nothing}
    substitution_group::Union{String,Nothing}
    concept_type::Union{String,Nothing}
    abstract::Union{Bool,Nothing}
    nillable::Union{Bool,Nothing}
    period_type::Union{String,Nothing}
    balance::Union{String,Nothing}
    labels::Vector{Label}

    Concept(
        role_id::AbstractString,
        uri::Union{AbstractString,Nothing},
        definition::AbstractString,
    ) = new(
        role_id,
        uri,
        definition,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        nothing,
        [],
    )
end

mutable struct ExtendedLinkRole
    xml_id::String
    uri::String
    definition::String
    definition_link::Union{ExtendedLink,Nothing}
    presentation_link::Union{ExtendedLink,Nothing}
    calculation_link::Union{ExtendedLink,Nothing}

    ExtendedLinkRole(
        role_id::AbstractString,
        uri::AbstractString,
        definition::AbstractString,
    ) = new(role_id, uri, definition, nothing, nothing, nothing)
end

mutable struct TaxonomySchema
    schema_url::String
    namespace::String
    imports::Vector{TaxonomySchema}
    link_roles::Vector{ExtendedLinkRole}
    lab_linkbases::Vector{Linkbase}
    def_linkbases::Vector{Linkbase}
    cal_linkbases::Vector{Linkbase}
    pre_linkbases::Vector{Linkbase}
    concepts::Dict{String,Concept}
    name_id_map::Dict{String,String}

    TaxonomySchema(schema_url::AbstractString, namespace::AbstractString) =
        new(schema_url, namespace, [], [], [], [], [], [], Dict(), Dict())
end

function gettaxonomylut!(schema::TaxonomySchema, lut::Dict)
    if !(haskey(lut, schema.namespace))
        lut[schema.namespace] = schema
    end
    if !(haskey(lut, schema.schema_url))
        lut[schema.schema_url] = schema
    end
    for importedtax in schema.imports
        gettaxonomylut!(importedtax, lut)
    end
end

function parsecommontaxonomy(cache::HttpCache, namespace)::Union{TaxonomySchema,Nothing}
    haskey(NS_SCHEMA_MAP, namespace) &&
        return parsetaxonomy_url(NS_SCHEMA_MAP[namespace], cache)
    return nothing
end

@memoize LRU{Tuple{AbstractString,HttpCache},TaxonomySchema}(maxsize = 60) function parsetaxonomy_url(
    schema_url::AbstractString,
    cache::HttpCache,
)::TaxonomySchema
    !startswith(schema_url, "http") &&
        throw("This function only parses remotely saved taxonomies.")
    schema_path::AbstractString = cachefile(cache, schema_url)
    return parsetaxonomy(schema_path, cache, schema_url)
end

"""
    parsetaxonomy(schema_path, cache::HttpCache, schema_url=nothing)::TaxonomySchema

Parse a given taxonomy
"""
function parsetaxonomy(schema_path, cache::HttpCache, schema_url = nothing)::TaxonomySchema

    # Implement errors
    ns_schema_map::Dict{String,String} = NS_SCHEMA_MAP
    doc::EzXML.Document = readxml(schema_path)
    root::EzXML.Node = doc.root
    target_ns::AbstractString = root["targetNamespace"]

    taxonomy::TaxonomySchema =
        schema_url isa Nothing ? TaxonomySchema(schema_path, target_ns) :
        TaxonomySchema(schema_url, target_ns)

    import_elements::Vector{EzXML.Node} = findall("xsd:import", root, NAME_SPACES)

    for import_element in import_elements
        import_uri = import_element["schemaLocation"]
        if startswith(import_uri, "http")
            push!(taxonomy.imports, parsetaxonomy_url(import_uri, cache))
        elseif !(schema_url isa Nothing)
            import_url = resolve_uri(schema_url, import_uri)
            push!(taxonomy.imports, parsetaxonomy_url(import_url, cache))
        else
            import_path = resolve_uri(schema_path, import_uri)
            push!(taxonomy.imports, parsetaxonomy(import_path, cache))
        end
    end

    role_type_elements::Vector{EzXML.Node} =
        findall("xsd:annotation/xsd:appinfo/link:roleType", root, NAME_SPACES)

    for elr in role_type_elements
        elr_definition = findfirst("link:definition", elr, NAME_SPACES)
        (elr_definition isa Nothing || elr_definition.content == "") && continue
        push!(
            taxonomy.link_roles,
            ExtendedLinkRole(elr["id"], elr["roleURI"], strip(elr_definition.content)),
        )
    end

    for element in findall("xsd:element", root, NAME_SPACES)
        (!haskey(element, "id") || !(haskey(element, "name"))) && continue
        el_id::String = element["id"]
        el_name::String = element["name"]

        concept::Concept = Concept(el_id, schema_url, el_name)
        concept.type = haskey(element, "type") ? element["type"] : nothing
        concept.nillable =
            haskey(element, "nillable") ? parse(Bool, element["nillable"]) : false
        concept.abstract =
            haskey(element, "abstract") ? parse(Bool, element["abstract"]) : false
        concept.period_type =
            haskey(element, "xbrli:periodType") ? element["xbrli:periodType"] : nothing
        concept.balance =
            haskey(element, "xbrli:balance") ? element["xbrli:balance"] : nothing
        concept.substitution_group =
            haskey(element, "substitutionGroup") ?
            split(element["substitutionGroup"], ":")[end] : nothing

        taxonomy.concepts[concept.xml_id] = concept
        taxonomy.name_id_map[concept.name] = concept.xml_id
    end

    linkbase_ref_elements::Vector{EzXML.Node} =
        findall("xsd:annotation/xsd:appinfo/link:linkbaseRef", root, NAME_SPACES)
    for linkbase_ref in linkbase_ref_elements
        linkbase_uri = linkbase_ref["xlink:href"]
        role = haskey(linkbase_ref, "xlink:role") ? linkbase_ref["xlink:role"] : nothing
        linkbase_type =
            role isa Nothing ? Linkbases.guess_linkbase_role(linkbase_uri) :
            Linkbases.get_type_from_role(role)

        if startswith(linkbase_uri, "http")
            linkbase = parselinkbase_url(linkbase_uri, linkbase_type, cache)
        elseif !(schema_url isa Nothing)
            linkbase_url = resolve_uri(schema_url, linkbase_uri)
            linkbase = parselinkbase_url(linkbase_url, linkbase_type, cache)
        else
            linkbase_path = resolve_uri(schema_path, linkbase_uri)
            linkbase = parselinkbase(linkbase_path, linkbase_type)
        end

        linkbase_type == Linkbases.DEFINITION && push!(taxonomy.def_linkbases, linkbase)
        linkbase_type == Linkbases.CALCULATION && push!(taxonomy.cal_linkbases, linkbase)
        linkbase_type == Linkbases.PRESENTATION && push!(taxonomy.pre_linkbases, linkbase)
        linkbase_type == Linkbases.LABEL && push!(taxonomy.lab_linkbases, linkbase)

    end

    for elr in taxonomy.link_roles
        for extended_def_links in
            [def_linkbase.extended_links for def_linkbase in taxonomy.def_linkbases]
            for extended_def_link in extended_def_links
                if split(extended_def_link.elr_id, "#")[2] == elr.xml_id
                    elr.definition_link = extended_def_link
                    break
                end
            end
        end
        for extended_pre_links in
            [pre_linkbase.extended_links for pre_linkbase in taxonomy.pre_linkbases]
            for extended_pre_link in extended_pre_links
                if split(extended_pre_link.elr_id, "#")[2] == elr.xml_id
                    elr.presentation_link = extended_pre_link
                    break
                end
            end
        end
        for extended_cal_links in
            [cal_linkbase.extended_links for cal_linkbase in taxonomy.cal_linkbases]
            for extended_cal_link in extended_cal_links
                if split(extended_cal_link.elr_id, "#")[2] == elr.xml_id
                    elr.calculation_link = extended_cal_link
                    break
                end
            end
        end
    end

    for label_linkbase in taxonomy.lab_linkbases
        for extended_link in label_linkbase.extended_links
            for root_locator in extended_link.root_locators
                (schema_url, concept_id) = split(unescapeuri(root_locator.href), "#")
                taxonomylut::Dict{AbstractString,TaxonomySchema} = Dict()
                gettaxonomylut!(taxonomy, taxonomylut)
                normaliseuri!(taxonomylut)
                c_taxonomy::Union{TaxonomySchema,Nothing} =
                    get(taxonomylut, normaliseuri(schema_url), nothing)

                if c_taxonomy isa Nothing
                    if schema_url in values(ns_schema_map)
                        c_taxonomy = parsetaxonomy_url(schema_url, cache)
                        push!(taxonomy.imports, c_taxonomy)
                    else
                        continue
                    end
                end

                concept::Concept = c_taxonomy.concepts[concept_id]

                for label_arc in root_locator.children
                    for label in label_arc.labels
                        push!(concept.labels, label)
                    end
                end
            end
        end
    end

    return taxonomy
end

Base.show(io::IO, c::Concept) = print(io, c.name)
Base.show(io::IO, elr::ExtendedLinkRole) = print(io, elr.definition)
Base.show(io::IO, ts::TaxonomySchema) = print(io, ts.namespace)

end # Module
