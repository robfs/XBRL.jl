using XbrlXML
using Test
using Documenter

@testset verbose = true "XbrlXML.jl" begin
    @testset "Cache" begin
        cachedir::String = abspath("./cache/") * "/"
        cache::HttpCache = HttpCache(cachedir)
        testurl::String = "https://www.w3schools.com/xml/note.xml"
        expectedpath::String = cachedir * "www.w3schools.com/xml/note.xml"
        rm(expectedpath; force = true)
        @test cachefile(cache, testurl) == expectedpath
        @test isfile(expectedpath)
        @test purgefile(cache, testurl)
        @test !(isfile(expectedpath))
        rm(cachedir; force = true, recursive = true)
    end
    @testset verbose = true "Linkbases" begin
        @testset "Local Linkbases" begin
            linkbasepath::String = abspath("./data/example-lab.xml")
            linkbase::XbrlXML.Linkbase =
                parselinkbase(linkbasepath, XbrlXML.Linkbases.LABEL)
            rootlocator::XbrlXML.Locator = linkbase.extended_links[1].root_locators[1]
            @test length(linkbase.extended_links) == 1
            @test rootlocator.name == "loc_Assets"
            labelarcs::Vector{XbrlXML.LabelArc} = rootlocator.children
            @test labelarcs[1].labels[1].text == "Assets, total"
            @test occursin(
                "An asset is a resource with economic value",
                labelarcs[2].labels[1].text,
            )
            linkbasepath = abspath("./data/example-cal.xml")
            linkbase = parselinkbase(linkbasepath, XbrlXML.Linkbases.CALCULATION)
            assetslocator::XbrlXML.Locator = linkbase.extended_links[1].root_locators[1]
            @test assetslocator.concept_id == "example_Assets"
            @test assetslocator.children[1].to_locator.concept_id ==
                  "example_NonCurrentAssets"
            @test assetslocator.children[2].to_locator.concept_id == "example_CurrentAssets"
        end
        if isfile(abspath("./.env"))
            @testset "Remote Linkbases" begin
                cachedir::String = abspath("./cache/")
                cache::HttpCache = HttpCache(cachedir)
                header!(cache, "User-Agent" => "Test test@test.com")
                linkbaseurl::String = "https://www.esma.europa.eu/taxonomy/2019-03-27/esef_cor-lab-de.xml"
                linkbase = parselinkbase_url(linkbaseurl, XbrlXML.Linkbases.LABEL, cache)
                @test length(linkbase.extended_links) == 1
                @test length(linkbase.extended_links[1].root_locators) == 5028
                assetslocator = filter(
                    x -> x.name == "Assets",
                    linkbase.extended_links[1].root_locators,
                )[1]
                assetslabel::XbrlXML.Label = assetslocator.children[1].labels[1]
                @test assetslabel.text == "Vermögenswerte"
                rm(cachedir; force = true, recursive = true)
            end
        end
    end
    @testset verbose = true "Taxonomies" begin
        @testset "Local Taxonomies" begin
            cachedir::String = abspath("./cache/")
            cache::HttpCache = HttpCache(cachedir)
            extensionschemapath::String = abspath("./data/example.xsd")
            tax::XbrlXML.TaxonomySchema = parsetaxonomy(extensionschemapath, cache)
            taxonomylut::Dict{AbstractString,XbrlXML.TaxonomySchema} = Dict()
            XbrlXML.Taxonomy.gettaxonomylut!(tax, taxonomylut)
            XbrlXML.Taxonomy.normaliseuri!(taxonomylut)
            srttax::XbrlXML.TaxonomySchema = get(
                taxonomylut,
                XbrlXML.Taxonomy.normaliseuri("http://fasb.org/srt/2020-01-31"),
                nothing,
            )
            @test length(srttax.concepts) == 489
            @test length(tax.concepts["example_Assets"].labels) == 2
        end
        if isfile(abspath("./.env"))
            @testset "Remote Taxonomies" begin
                cachedir::String = abspath("./cache/")
                cache::HttpCache = HttpCache(cachedir)
                header!(cache, "User-Agent" => "Test test@test.com")
                schemaurl::String = "https://www.sec.gov/Archives/edgar/data/320193/000032019321000010/aapl-20201226.xsd"
                tax = parsetaxonomy_url(schemaurl, cache)
                @test length(tax.concepts) == 65
                taxonomylut::Dict{AbstractString,XbrlXML.TaxonomySchema} = Dict()
                XbrlXML.gettaxonomylut!(tax, taxonomylut)
                XbrlXML.Taxonomy.normaliseuri!(taxonomylut)
                usgaaptax::XbrlXML.TaxonomySchema = get(
                    taxonomylut,
                    XbrlXML.Taxonomy.normaliseuri("http://fasb.org/us-gaap/2020-01-31"),
                    nothing,
                )
                @test length(usgaaptax.concepts) == 17281
                @test length(tax.concepts["aapl_MacMember"].labels) == 3
                rm(cachedir; force = true, recursive = true)
            end
        end
    end
    @testset "Transformations" begin
        testtransforms::Dict{String,Vector} = Dict([
            "http://www.xbrl.org/inlineXBRL/transformation/2015-02-26" => [
                # [format,value,expected]
                ["booleanfalse", "nope", "false"],
                ["booleantrue", "yeah", "true"],
                ["datedaymonth", "11.12", "--12-11"],
                ["datedaymonth", "1.2", "--02-01"],
                ["datedaymonthen", "2. December", "--12-02"],
                ["datedaymonthen", "2 Sept.", "--09-02"],
                ["datedaymonthen", "14.    april", "--04-14"],
                ["datedaymonthyear", "2.12.2021", "2021-12-02"],
                ["datedaymonthyear", "1.1.99", "1999-01-01"],
                ["datedaymonthyear", "18. 02 2022", "2022-02-18"],
                ["datedaymonthyearen", "02. December 2021", "2021-12-02"],
                ["datedaymonthyearen", "13. Dec. 21", "2021-12-13"],
                ["datedaymonthyearen", "1 Feb 99", "1999-02-01"],
                ["datemonthday", "1.2", "--01-02"],
                ["datemonthday", "12-1", "--12-01"],
                ["datemonthday", "1.30", "--01-30"],
                ["datemonthdayen", "Jan 02", "--01-02"],
                ["datemonthdayen", "February 13", "--02-13"],
                ["datemonthdayen", "sept. 1", "--09-01"],
                ["datemonthdayyear", "12-30-2021", "2021-12-30"],
                ["datemonthdayyear", "2-16-22", "2022-02-16"],
                ["datemonthdayyear", "2-1-2019", "2019-02-01"],
                ["datemonthdayyearen", "March 31, 2021", "2021-03-31"],
                ["datemonthdayyearen", "Dec. 31, 22", "2022-12-31"],
                ["datemonthdayyearen", "april 12 2021", "2021-04-12"],
                ["datemonthyear", "12 2021", "2021-12"],
                ["datemonthyear", "1 22", "2022-01"],
                ["datemonthyear", "02-1999", "1999-02"],
                ["datemonthyearen", "December 2021", "2021-12"],
                ["datemonthyearen", "apr. 22", "2022-04"],
                ["datemonthyearen", "Sept. 2000", "2000-09"],
                ["dateyearmonthday", "2021.12.31", "2021-12-31"],
                ["dateyearmonthday", "2021 1  31", "2021-01-31"],
                ["dateyearmonthday", "22-1-1", "2022-01-01"],
                ["dateyearmonthen", "2021 December", "2021-12"],
                ["dateyearmonthen", "22 sept.", "2022-09"],
                ["dateyearmonthen", "21.apr.", "2021-04"],
                ["nocontent", "Bla bla", ""],
                ["numcommadecimal", "1.499,99", "1499.99"],
                ["numcommadecimal", "100*499,999", "100499.999"],
                ["numcommadecimal", "0,5", "0.5"],
                ["numdotdecimal", "1,499.99", "1499.99"],
                ["numdotdecimal", "1*499", "1499"],
                ["numdotdecimal", "1,000,000.5", "1000000.5"],
                ["zerodash", "--", "0"],
            ],
            "http://www.xbrl.org/inlineXBRL/transformation/2020-02-12" => [
                # [format,value,expected]
                ["date-day-month", "1.1", "--01-01"],
                ["date-day-month", "31-12", "--12-31"],
                ["date-day-month", "27*2", "--02-27"],
                ["date-day-month-year", "1-2-20", "2020-02-01"],
                ["date-day-month-year", "1-02-20", "2020-02-01"],
                ["date-day-month-year", "01 02 2020", "2020-02-01"],
                ["date-day-monthname-en", "1. sept.", "--09-01"],
                ["date-day-monthname-en", "01. sep.", "--09-01"],
                ["date-day-monthname-en", "30 August", "--08-30"],
                ["date-day-monthname-year-en", "30 August 22", "2022-08-30"],
                ["date-day-monthname-year-en", "01 Aug 22", "2022-08-01"],
                ["date-day-monthname-year-en", "1 Aug 2022", "2022-08-01"],
                ["date-month-day", "1 31", "--01-31"],
                ["date-month-day", "01-31", "--01-31"],
                ["date-month-day", "12.1", "--12-01"],
                ["date-month-day-year", "12. 1 22", "2022-12-01"],
                ["date-month-day-year", "01/12/2022", "2022-01-12"],
                ["date-month-day-year", "01.12.2022", "2022-01-12"],
                ["date-month-year", "1*22", "2022-01"],
                ["date-month-year", "01  22", "2022-01"],
                ["date-month-year", "12.2022", "2022-12"],
                ["date-monthname-day-en", "April/1", "--04-01"],
                ["date-monthname-day-en", "Sept./20", "--09-20"],
                ["date-monthname-day-en", "december 31", "--12-31"],
                ["date-monthname-day-year-en", "december 31, 22", "2022-12-31"],
                ["date-monthname-day-year-en", "dec. 31, 2022", "2022-12-31"],
                ["date-monthname-day-year-en", "dec. 1, 2022", "2022-12-01"],
                ["date-year-month", "99/1", "1999-01"],
                ["date-year-month", "2022 - 12", "2022-12"],
                ["date-year-month", "2022 -/ 1", "2022-01"],
                ["date-year-month-day", "   22-1-2 ", "2022-01-02"],
                ["date-year-month-day", " 2022/1/2 ", "2022-01-02"],
                ["date-year-month-day", "  22/01/02 ", "2022-01-02"],
                ["date-year-monthname-en", "22/december", "2022-12"],
                ["date-year-monthname-en", "22/dec.", "2022-12"],
                ["date-year-monthname-en", "2022-dec", "2022-12"],
                ["fixed-empty", "some text", ""],
                ["fixed-false", "some text", "false"],
                ["fixed-true", "some text", "true"],
                ["fixed-zero", "some text", "0"],
                ["num-comma-decimal", "1.499,99", "1499.99"],
                ["num-comma-decimal", "100*499,999", "100499.999"],
                ["num-comma-decimal", "0,5", "0.5"],
                ["num-dot-decimal", "1,499.99", "1499.99"],
                ["num-dot-decimal", "1*499", "1499"],
                ["num-dot-decimal", "1,000,000.5", "1000000.5"],
            ],
            "http://www.sec.gov/inlineXBRL/transformation/2015-08-31" => [
                # [format,value,expected]
                ["duryear", "-22.3456", "-P22Y4M4D"],
                ["duryear", "21.84480", "P21Y10M5D"],
                ["duryear", "+0.3456", "P0Y4M4D"],
                ["durmonth", "22.3456", "P22M10D"],
                ["durmonth", "-0.3456", "-P0M10D"],
                ["durwordsen", "Five years, two months", "P5Y2M0D"],
                ["durwordsen", "9 years, 2 months", "P9Y2M0D"],
                ["durwordsen", "12 days", "P0Y0M12D"],
                ["durwordsen", "ONE MONTH AND THREE DAYS", "P0Y1M3D"],
                ["numwordsen", "no", "0"],
                ["numwordsen", "None", "0"],
                ["numwordsen", "nineteen hundred forty-four", "1944"],
                ["numwordsen", "Seventy Thousand and one", "70001"],
                ["boolballotbox", "☐", "false"],
                ["boolballotbox", "&#9744;", "false"],
                ["boolballotbox", "☑", "true"],
                ["boolballotbox", "&#9745;", "true"],
                ["boolballotbox", "☒", "true"],
                ["boolballotbox", "&#9746;", "true"],
                ["exchnameen", "The New York Stock Exchange", "NYSE"],
                ["exchnameen", "New York Stock Exchange LLC", "NYSE"],
                ["exchnameen", "NASDAQ Global Select Market", "NASDAQ"],
                ["exchnameen", "The Nasdaq Stock Market LLC", "NASDAQ"],
                ["exchnameen", "BOX Exchange LLC", "BOX"],
                ["exchnameen", "Nasdaq BX, Inc.", "BX"],
                ["exchnameen", "Cboe C2 Exchange, Inc.", "C2"],
                ["exchnameen", "Cboe Exchange, Inc.", "CBOE"],
                ["exchnameen", "Chicago Stock Exchange, Inc.", "CHX"],
                ["exchnameen", "Cboe BYX Exchange, Inc.", "CboeBYX"],
                ["exchnameen", "Cboe BZX Exchange, Inc.", "CboeBZX"],
                ["exchnameen", "Cboe EDGA Exchange, Inc.", "CboeEDGA"],
                ["exchnameen", "Cboe EDGX Exchange, Inc.", "CboeEDGX"],
                ["exchnameen", "Nasdaq GEMX, LLC", "GEMX"],
                ["exchnameen", "Investors Exchange LLC", "IEX"],
                ["exchnameen", "Nasdaq ISE, LLC", "ISE"],
                ["exchnameen", "Miami International Securities Exchange", "MIAX"],
                ["exchnameen", "Nasdaq MRX, LLC", "MRX"],
                ["exchnameen", "NYSE American LLC", "NYSEAMER"],
                ["exchnameen", "NYSE Arca, Inc.", "NYSEArca"],
                ["exchnameen", "NYSE National, Inc.", "NYSENAT"],
                ["exchnameen", "MIAX PEARL, LLC", "PEARL"],
                ["exchnameen", "Nasdaq PHLX LLC", "Phlx"],
                ["stateprovnameen", "Alabama", "AL"],
                ["stateprovnameen", "Alaska", "AK"],
                ["stateprovnameen", "Arizona", "AZ"],
                ["stateprovnameen", "Arkansas", "AR"],
                ["stateprovnameen", "California", "CA"],
                ["stateprovnameen", "Colorado", "CO"],
                ["stateprovnameen", "Connecticut", "CT"],
                ["stateprovnameen", "Delaware", "DE"],
                ["stateprovnameen", "Florida", "FL"],
                ["stateprovnameen", "Georgia", "GA"],
                ["stateprovnameen", "Hawaii", "HI"],
                ["stateprovnameen", "Idaho", "ID"],
                ["stateprovnameen", "Illinois", "IL"],
                ["stateprovnameen", "Indiana", "IN"],
                ["stateprovnameen", "Iowa", "IA"],
                ["stateprovnameen", "Kansas", "KS"],
                ["stateprovnameen", "Kentucky", "KY"],
                ["stateprovnameen", "Louisiana", "LA"],
                ["stateprovnameen", "Maine", "ME"],
                ["stateprovnameen", "Maryland", "MD"],
                ["stateprovnameen", "Massachusetts", "MA"],
                ["stateprovnameen", "Michigan", "MI"],
                ["stateprovnameen", "Minnesota", "MN"],
                ["stateprovnameen", "Mississippi", "MS"],
                ["stateprovnameen", "Missouri", "MO"],
                ["stateprovnameen", "Montana", "MT"],
                ["stateprovnameen", "Nebraska", "NE"],
                ["stateprovnameen", "Nevada", "NV"],
                ["stateprovnameen", "New Hampshire", "NH"],
                ["stateprovnameen", "New Jersey", "NJ"],
                ["stateprovnameen", "New Mexico", "NM"],
                ["stateprovnameen", "New York", "NY"],
                ["stateprovnameen", "North Carolina", "NC"],
                ["stateprovnameen", "North Dakota", "ND"],
                ["stateprovnameen", "Ohio", "OH"],
                ["stateprovnameen", "Oklahoma", "OK"],
                ["stateprovnameen", "Oregon", "OR"],
                ["stateprovnameen", "Pennsylvania", "PA"],
                ["stateprovnameen", "Rhode Island", "RI"],
                ["stateprovnameen", "South Carolina", "SC"],
                ["stateprovnameen", "South dakota", "SD"],
                ["stateprovnameen", "Tennessee", "TN"],
                ["stateprovnameen", "Texas", "TX"],
                ["stateprovnameen", "Utah", "UT"],
                ["stateprovnameen", "Vermont", "VT"],
                ["stateprovnameen", "Virginia", "VA"],
                ["stateprovnameen", "Washington", "WA"],
                ["stateprovnameen", "Washington D.C.", "DC"],
                ["stateprovnameen", "West Virginia", "WV"],
                ["stateprovnameen", "Wisconsin", "WI"],
                ["stateprovnameen", "Wyoming", "WY"],
                ["entityfilercategoryen", "accelerated filer", "Accelerated Filer"],
            ],
        ])
        for (namespace, transforms) in testtransforms
            for testcase in transforms
                (formatcode, input, expected) = testcase
                if expected == "exception"
                    @test_throws AbstractTransformationException XbrlXML.Instance.normalize(
                        namespace,
                        formatcode,
                        input,
                    )
                else
                    received::String =
                        XbrlXML.Instance.normalize(namespace, formatcode, input)
                    @test expected == received
                end
            end
        end
    end

    @testset verbose = true "URI Helpers" begin
        @testset "Resolver" begin
            test_arr = [
                # test paths
                (
                    (
                        "E:\\Programming\\python\\xbrl_parser\\tests\\data\\example.xsd",
                        "/example-lab.xml",
                    ),
                    join(
                        [
                            "E:",
                            "Programming",
                            "python",
                            "xbrl_parser",
                            "tests",
                            "data",
                            "example-lab.xml",
                        ],
                        Base.Filesystem.path_separator,
                    ),
                ),
                (
                    (
                        raw"E:\Programming\python\xbrl_parser\tests\data\example.xsd",
                        "/example-lab.xml",
                    ),
                    join(
                        [
                            "E:",
                            "Programming",
                            "python",
                            "xbrl_parser",
                            "tests",
                            "data",
                            "example-lab.xml",
                        ],
                        Base.Filesystem.path_separator,
                    ),
                ),
                (
                    (
                        "E:/Programming/python/xbrl_parser/tests/data/example.xsd",
                        "/example-lab.xml",
                    ),
                    join(
                        [
                            "E:",
                            "Programming",
                            "python",
                            "xbrl_parser",
                            "tests",
                            "data",
                            "example-lab.xml",
                        ],
                        Base.Filesystem.path_separator,
                    ),
                ),
                # test different path separators
                (
                    (
                        "E:\\Programming\\python\\xbrl_parser\\tests\\data/example.xsd",
                        "/example-lab.xml",
                    ),
                    join(
                        [
                            "E:",
                            "Programming",
                            "python",
                            "xbrl_parser",
                            "tests",
                            "data",
                            "example-lab.xml",
                        ],
                        Base.Filesystem.path_separator,
                    ),
                ),
                # test directory traversal
                (
                    (
                        "E:/Programming/python/xbrl_parser/tests/data/",
                        "/../example-lab.xml",
                    ),
                    join(
                        [
                            "E:",
                            "Programming",
                            "python",
                            "xbrl_parser",
                            "tests",
                            "example-lab.xml",
                        ],
                        Base.Filesystem.path_separator,
                    ),
                ),
                (
                    (
                        "E:/Programming/python/xbrl_parser/tests/data",
                        "./../example-lab.xml",
                    ),
                    join(
                        [
                            "E:",
                            "Programming",
                            "python",
                            "xbrl_parser",
                            "tests",
                            "example-lab.xml",
                        ],
                        Base.Filesystem.path_separator,
                    ),
                ),
                (
                    (
                        "E:/Programming/python/xbrl_parser/tests/data/example.xsd",
                        "../../example-lab.xml",
                    ),
                    join(
                        ["E:", "Programming", "python", "xbrl_parser", "example-lab.xml"],
                        Base.Filesystem.path_separator,
                    ),
                ),
                # test urls
                (
                    ("http://example.com/a/b/c/d/e/f/g", "file.xml"),
                    "http://example.com/a/b/c/d/e/f/g/file.xml",
                ),
                (
                    ("http://example.com/a/b/c/d/e/f/g", "/file.xml"),
                    "http://example.com/a/b/c/d/e/f/g/file.xml",
                ),
                (
                    ("http://example.com/a/b/c/d/e/f/g", "./file.xml"),
                    "http://example.com/a/b/c/d/e/f/g/file.xml",
                ),
                (
                    ("http://example.com/a/b/c/d/e/f/g", "../file.xml"),
                    "http://example.com/a/b/c/d/e/f/file.xml",
                ),
                (
                    ("http://example.com/a/b/c/d/e/f/g", "/../file.xml"),
                    "http://example.com/a/b/c/d/e/f/file.xml",
                ),
                (
                    ("http://example.com/a/b/c/d/e/f/g", "./../file.xml"),
                    "http://example.com/a/b/c/d/e/f/file.xml",
                ),
                (
                    ("http://example.com/a/b/c/d/e/f/g", "../../file.xml"),
                    "http://example.com/a/b/c/d/e/file.xml",
                ),
                (
                    ("http://example.com/a/b/c/d/e/f/g", "/../../file.xml"),
                    "http://example.com/a/b/c/d/e/file.xml",
                ),
                (
                    ("http://example.com/a/b/c/d/e/f/g", "./../../file.xml"),
                    "http://example.com/a/b/c/d/e/file.xml",
                ),
                (
                    ("http://example.com/a/b/c/d/e/f/g/", "../../../file.xml"),
                    "http://example.com/a/b/c/d/file.xml",
                ),
                (
                    ("http://example.com/a/b/c/d/e/f/g.xml", "../../../file.xml"),
                    "http://example.com/a/b/c/file.xml",
                ),
            ]
            for elem in test_arr
                # only windows uses the \\ file path separator
                # for now skip the first tests with \\ if we are on a unix system, since the \\ is an invalid path on
                # a unix like os such as macOS or linux
                if startswith(elem[1][1], "E:\\") && Base.Filesystem.path_separator != "\\"
                    # @info "Skipping Windows specific unit test case"
                    continue
                end
                expected = elem[2]
                received = XbrlXML.Taxonomy.resolve_uri(elem[1][1], elem[1][2])
                @test expected == received
            end
        end
        @testset "Comparisons" begin
            test_arr = [
                ["./abc", "abc", true],
                ["./abc", "\\abc\\", true],
                ["./abc", "abcd", false],
                ["http://abc.de", "https://abc.de", true],
            ]
            for test_case in test_arr
                expected = test_case[3]
                received = XbrlXML.Taxonomy.compare_uri(test_case[1], test_case[2])
                @test expected == received
            end
        end
    end
    @testset verbose = true "Instance Tests" begin
        @testset "Local Instances" begin
            cachedir::String = abspath("./cache/")
            cache::HttpCache = HttpCache(cachedir)
            instancedocurl::String = "./data/example.xml"
            inst::XbrlInstance = parsexbrl(instancedocurl, cache)
            @test length(facts(inst)) == 1
            instancedocurl = "./data/example.html"
            inst = parseixbrl(instancedocurl, cache)
            @test length(facts(inst)) == 3
        end
        if isfile(abspath("./.env"))
            @testset "Remote Instances" begin
                cachedir::String = abspath("./cache/")
                cache::HttpCache = HttpCache(cachedir)
                header!(cache, "User-Agent" => "Test test@test.com")
                url::String = "https://www.sec.gov/Archives/edgar/data/320193/000032019321000010/aapl-20201226.htm"
                inst = parseixbrl_url(url, cache)
                @test length(inst.context_map) == 207
                @test length(inst.unit_map) == 9
                rm(cachedir; force = true, recursive = true)
            end
        end
    end
    doctest(XbrlXML)
end
