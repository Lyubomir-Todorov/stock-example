import 'dart:html';
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:modern_charts/modern_charts.dart';

//Key obtained from the following API service:
//https://finnhub.io/
const key = '';


class Stock {
  String name, country, exchange, url, category, logo;
  double priceOpen, priceHigh, priceLow, priceCurrent, pricePrevious;

  Stock({this.name, this.country, this.exchange, this.url, this.category, this.logo, this.priceOpen, this.priceHigh, this.priceLow, this.pricePrevious});
}

class Candle {
  List date, price;

  Candle ({this.date, this.price});
}

class Article {
  String datePublished, headline, summary, source, url;

  Article({this.datePublished, this.headline, this.summary, this.source, this.url});
}

void main() async {

  querySelector('#search').onClick.listen((e) async { //Display results
    loadResults();
  });

  querySelector('#symbol').onKeyDown.listen((e) { //Clear error message on text field update
    querySelector('#error').text = '';
  });
}



Future <Stock> getStockQuote(symbol) async { //Information about the stock's opening, current price

  var url = 'https://finnhub.io/api/v1/quote?symbol=${symbol}&token=${key}';
  var response = await http.get(url);

  if (response.statusCode == 200) { //Constructs Stock object
    var returnObject = Stock();
    var jsonResponse = jsonDecode(response.body);

    returnObject.priceOpen = jsonResponse['o'];
    returnObject.priceHigh = jsonResponse['h'];
    returnObject.priceLow = jsonResponse['l'];
    returnObject.priceCurrent = jsonResponse['c'];
    returnObject.pricePrevious = jsonResponse['pc'];

    return returnObject;
  } else {
    throw Exception('Error: Failed to fetch financial for ${symbol}');
  }

}

Future <Stock> getStockOverview(symbol) async { //Information about the stock's profile, company, market, logo

  var url = 'https://finnhub.io/api/v1/stock/profile2?symbol=${symbol}&token=${key}';
  var response = await http.get(url);

  if (response.statusCode == 200) { //Adds to previously constructed stock
    var returnObject = await getStockQuote(symbol);
    var jsonResponse = jsonDecode(response.body);

    returnObject.name = jsonResponse['name'];
    returnObject.country = jsonResponse['country'];
    returnObject.exchange = jsonResponse['exchange'];
    returnObject.url = jsonResponse['weburl'];
    returnObject.category = jsonResponse['finnhubIndustry'];
    returnObject.logo = jsonResponse['logo'];

    return returnObject;

  } else {
    throw Exception('Error: Failed to fetch company overview for ${symbol}');
  }
}

Future <Candle> getStockCandle(symbol) async { //Information about the stocks closing price over the selected time span

  //Retrieve information from today's date to 1 year prior
  var start,finish;
  start =  DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day).millisecondsSinceEpoch / 1000;
  finish = DateTime.utc(DateTime.now().year-1, DateTime.now().month, DateTime.now().day).millisecondsSinceEpoch / 1000;

  var url = 'https://finnhub.io/api/v1/forex/candle?symbol=${symbol}&resolution=W&from=${finish}&to=${start}&token=${key}';
  var response = await http.get(url);

  if (response.statusCode == 200) { //Constructs candle object

    var returnObject = Candle();
    var jsonResponse = jsonDecode(response.body);

    returnObject.date = jsonResponse['t'];
    returnObject.price = jsonResponse['c'];

    return returnObject;

  } else {
    throw Exception('Error: Failed to fetch previous data for ${symbol}');
  }
}

Future <List> getPeers(symbol) async { //Related stocks
  var url = 'https://finnhub.io/api/v1/stock/peers?symbol=${symbol}&token=${key}';
  var response = await http.get(url);

  if (response.statusCode == 200) { //Returns list of related stock symbols
    List jsonResponse = jsonDecode(response.body);
    jsonResponse.remove(symbol); //Removes currently searched stock from related ones
    return jsonResponse;

  } else {
    throw Exception('Error: Failed to fetch similar symbols for ${symbol}');
  }
}

Future <List<Article>> getNews(symbol) async { //Related news articles

  //Dates in yyyy-mm-dd format
  var today = DateTime.now().toUtc().toString().substring(0,10);
  var monthAgo = DateTime.utc(DateTime.now().year, DateTime.now().month-1, DateTime.now().day).toUtc().toString().substring(0,10);

  //Retrieve related articles
  var url = 'https://finnhub.io/api/v1/company-news?symbol=${symbol}&from=${monthAgo}&to=${today}&token=${key}';
  var response = await http.get(url);

  if (response.statusCode == 200) {

    List<Article> returnList = [];
    List jsonResponse = jsonDecode(response.body);
    jsonResponse.forEach((f) {
      var article = Article()
          ..headline = f['headline'].toString()
          ..source = f['source'].toString()
          ..datePublished = f['datetime'].toString()
          ..summary = f['summary'].toString()
          ..url = f['url'].toString();
      returnList.add(article);
    });
    return returnList;
  } else {
    throw Exception('Error: Failed to fetch news for ${symbol}');
  }
}



void loadResults() async {
  try {
    var symbol = (querySelector('#symbol') as TextInputElement).value.toUpperCase();
    var stock = await getStockOverview(symbol);
    var candle = await getStockCandle(symbol);
    var peers = await getPeers(symbol);
    var articles = await getNews(symbol);

    if (stock.priceCurrent.toString() == 'null') {
      querySelector('#error').text = 'The following symbol could not be found';
    } else {
      querySelector('#financial-overview').style.opacity = '1';
      querySelector('#graph-overview').style.opacity = '1';
      querySelector('#similar-overview').style.opacity = '1';
      querySelector('#news-overview').style.opacity = '1';

      querySelector('#error').text = '';

      querySelector('#name').text = stock.name;
      querySelector('#exchange').text = stock.exchange;

      (querySelector('#logo') as ImageElement).src = stock.logo;
      (querySelector('#logo') as ImageElement).alt = '${stock.name} logo';

      querySelector('#priceCurrent').text = 'Current Price : ${stock.priceCurrent}';
      querySelector('#priceOpen').text = 'Opening Price : ${stock.priceOpen}';

      var difference = (stock.priceCurrent - stock.priceOpen);
      var percentage = ((difference / stock.priceOpen) * 100).toStringAsFixed(2);
      var symbolDifference = '';

      //Change price indicator styling based on price difference
      if (difference > 0) {
        symbolDifference = '▲';
        querySelector('#percentage').style.color = '#06d6a0';
      } else if (difference < 0) {
        symbolDifference = '▼';
        querySelector('#percentage').style.color = '#ef476f';
      }

      //Displays difference between opening and current price
      querySelector('#percentage').text = '$symbolDifference ${difference.toStringAsFixed(3)} (${percentage}%)';


      //Initialize graph
      querySelector('#graph').children.clear();

      List<List<dynamic>> candleData = [['Categories', 'Price']];

      for(var i = 0; i < candle.date.length; i ++) {
        var date = DateTime.fromMillisecondsSinceEpoch(candle.date[i] * 1000).toIso8601String().substring(2,10);

        if (!candle.price[i].toString().contains('.')) {
          candle.price[i] += 1e-6;
        }

        candleData.add([date, candle.price[i]]);
      }

      var table = DataTable(candleData);
      var chart = LineChart(querySelector('#graph'));

      var temp = candle.price;
      temp.sort();
      var high = temp.last;


      var options = {

        'xAxis' : {'labels' : {'minRotation' : 0, 'style' : {'color' : '#FEF9EF'}}},
        'yAxis': {'minInterval' : 0, 'maxInterval' : high + (high % 5), 'labels' : {'style' : {'color' : '#FEF9EF'}} },
        'tooltip': {'valueFormatter': (value) => '${(value.toString().split('.')[0] + '.' + value.toString().split('.')[1].substring(0,2))}'},
        'legend': {'position' : 'none', 'style' : {'color' : '#FEF9EF'}},
        'series' : {'markers' : {'size' : 0}},
        'colors' : ['#06d6a0'],


        'backgroundColor': '#4B4E6D',
      };


      chart.draw(table, options);

      //Initialize related stocks
      querySelector('#similar-overview').children.clear();
      for (var i = 0; i < peers.length; i ++) {
        var e = AnchorElement()
            ..className = 'clickable'
            ..id = 'peer'
            ..href = '#main'
            ..text = peers[i];
        querySelector('#similar-overview').insertAdjacentElement('beforeEnd', e);

        /*
        API sometimes formats non american stocks as the symbol name followed by dot market abbreviation
        For example, CM.TO is Toronto stock exchange
        Removes prefix of symbol before searching
        */

        e.onClick.listen((e) async {
          (querySelector('#symbol') as TextInputElement).value = peers[i].toString().split('.')[0];
          loadResults();
        });
      }


      var e = HeadingElement.h1()
        ..text = 'Stocks similar to this one';
      querySelector('#similar-overview').insertAdjacentElement('afterBegin', e);


      querySelector('#news-overview').children.clear();
      var f = HeadingElement.h1()
        ..text = 'Articles';
      querySelector('#news-overview').insertAdjacentElement('afterBegin', f);

      for(var i = 0; i < min(articles.length,5); i ++) {

        //Remove malformed apostrophes from news headlines and bodies
        articles[i].headline = articles[i].headline.replaceAll('&#39;', '\'');
        articles[i].summary = articles[i].summary.replaceAll('&#39;', '\'');

        var newsWrapper = DivElement()
          ..className = 'article';

        var anchor = AnchorElement()
          ..className = 'article'
          ..target = '_blank'
          ..href = articles[i].url;

        var title = HeadingElement.h1()
          ..text = articles[i].headline;

        var subtitle = HeadingElement.h4()
          ..text = '${articles[i].source} | ${DateTime.fromMillisecondsSinceEpoch(int.parse(articles[i].datePublished) * 1000).toIso8601String().substring(0,10)}';

        var content = ParagraphElement()
          ..text = articles[i].summary.substring(0, min(articles[i].summary.length, 500)) + '...';

        anchor.children.add(title);
        anchor.children.add(subtitle);
        anchor.children.add(content);

        newsWrapper.children.add(anchor);

        querySelector('#news-overview').insertAdjacentElement('beforeEnd', newsWrapper);
      }


    }
  } catch (err) {
    querySelector('#error').text = err.toString();
  }
}

