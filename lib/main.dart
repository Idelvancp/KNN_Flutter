import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

// Função para calcular a distância euclidiana entre dois pontos
double euclideanDistance(List<double> point1, List<double> point2) {
  double sum = 0.0;
  for (int i = 0; i < point1.length; i++) {
    sum += pow(point1[i] - point2[i], 2);
  }
  return sqrt(sum);
}

// Classe que representa o KNN
class KNN {
  int k;
  List<List<double>> trainingData;
  List<int> trainingLabels;

  // Construtor para inicializar o KNN com o valor de k, dados de treinamento e rótulos
  KNN(this.k, this.trainingData, this.trainingLabels);

  // Função para prever o rótulo de um novo ponto de dados
  int predict(List<double> newPoint) {
    // Lista para armazenar as distâncias e rótulos correspondentes
    List<Map<String, dynamic>> distances = [];

    // Calcular a distância de newPoint para todos os pontos de treinamento
    for (int i = 0; i < trainingData.length; i++) {
      double distance = euclideanDistance(newPoint, trainingData[i]);
      distances.add({'distance': distance, 'label': trainingLabels[i]});
    }

    // Ordenar as distâncias em ordem crescente
    distances.sort((a, b) => a['distance'].compareTo(b['distance']));

    // Verificar se há vizinhos suficientes
    if (distances.length < k) {
      throw RangeError("Não há vizinhos suficientes para k = $k");
    }

    // Selecionar os k vizinhos mais próximos
    List<int> kNearestLabels = [];
    for (int i = 0; i < k; i++) {
      kNearestLabels.add(distances[i]['label']);
    }

    // Contar a frequência de cada rótulo entre os k vizinhos mais próximos
    Map<int, int> labelCounts = {};
    for (int label in kNearestLabels) {
      if (!labelCounts.containsKey(label)) {
        labelCounts[label] = 0;
      }
      labelCounts[label] = labelCounts[label]! + 1;
    }

    // Encontrar o rótulo mais comum entre os k vizinhos mais próximos
    int predictedLabel = -1;
    int maxCount = 0;
    labelCounts.forEach((label, count) {
      if (count > maxCount) {
        maxCount = count;
        predictedLabel = label;
      }
    });

    return predictedLabel;
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KNN Classifier',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String predictedLabel = '';
  List<List<double>> trainingData = [];
  List<int> trainingLabels = [];
  List<String> testResults = [];
  bool isLoading = true;
  double accuracy = 0.0;
  double precision = 0.0;
  double recall = 0.0;
  double f1Score = 0.0;
  int knnTime = 0;
  int accuracyTime = 0;
  int precisionTime = 0;
  int recallTime = 0;
  int f1ScoreTime = 0;
  KNN? knn;
  final TextEditingController newSampleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadTrainingData();
  }

  // Função para carregar e processar o arquivo CSV
  Future<void> loadCSV() async {
    final rawData = await rootBundle.loadString('assets/data.csv');
    List<List<dynamic>> csvData = const CsvToListConverter().convert(rawData);
    print(csvData);
    // Remover a linha de cabeçalho, se houver
    print("Tamanho csv ${csvData.length}");
    csvData.removeAt(0);

    // Processar os dados do CSV
    for (var row in csvData) {
      List<double> features = [];
      for (var i = 0; i < row.length - 1; i++) {
        // Verificar e converter cada valor para double
        if (row[i] is String) {
          features.add(double.tryParse(row[i]) ?? 0.0);
        } else {
          features.add(row[i].toDouble());
        }
      }

      int label;
      // Verificar e converter o rótulo para int
      if (row.last is String) {
        label = int.tryParse(row.last) ?? 0;
      } else {
        label = row.last.toInt();
      }

      trainingData.add(features);
      trainingLabels.add(label);
    }

    // Salvar dados de treinamento e rótulos
    await saveTrainingData();

    setState(() {
      isLoading = false;
    });
  }

  // Função para salvar dados de treinamento e rótulos em SharedPreferences
  Future<void> saveTrainingData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> trainingDataString =
        trainingData.map((e) => jsonEncode(e)).toList();
    List<String> trainingLabelsString =
        trainingLabels.map((e) => e.toString()).toList();
    await prefs.setStringList('trainingData', trainingDataString);
    await prefs.setStringList('trainingLabels', trainingLabelsString);
  }

  // Função para carregar dados de treinamento e rótulos de SharedPreferences
  Future<void> loadTrainingData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? trainingDataString = prefs.getStringList('trainingData');
    List<String>? trainingLabelsString = prefs.getStringList('trainingLabels');

    if (trainingDataString != null && trainingLabelsString != null) {
      trainingData = trainingDataString
          .map((e) => List<double>.from(jsonDecode(e)))
          .toList();
      trainingLabels = trainingLabelsString.map((e) => int.parse(e)).toList();
      setState(() {
        isLoading = false;
      });
    } else {
      await loadCSV();
    }
  }

  void classifyAllPoints() {
    if (trainingData.isEmpty || trainingLabels.isEmpty) {
      return;
    }

    Stopwatch stopwatch = Stopwatch()..start();
    // Inicializar o KNN com k = 3
    knn = KNN(7, trainingData, trainingLabels);
    stopwatch.stop();
    knnTime = stopwatch.elapsedMilliseconds;

    stopwatch.reset();
    stopwatch.start();
    // Classificar todos os pontos de dados no conjunto de treinamento
    List<int> results = [];
    for (int i = 0; i < trainingData.length; i++) {
      int predicted = knn!.predict(trainingData[i]);
      results.add(predicted);
    }
    stopwatch.stop();
    knnTime += stopwatch.elapsedMilliseconds;

    stopwatch.reset();
    stopwatch.start();
    accuracy = calculateAccuracy(results, trainingLabels);
    stopwatch.stop();
    accuracyTime = stopwatch.elapsedMilliseconds;

    stopwatch.reset();
    stopwatch.start();
    precision = calculatePrecision(results, trainingLabels);
    stopwatch.stop();
    precisionTime = stopwatch.elapsedMilliseconds;

    stopwatch.reset();
    stopwatch.start();
    recall = calculateRecall(results, trainingLabels);
    stopwatch.stop();
    recallTime = stopwatch.elapsedMilliseconds;

    stopwatch.reset();
    stopwatch.start();
    f1Score = calculateF1Score(precision, recall);
    stopwatch.stop();
    f1ScoreTime = stopwatch.elapsedMilliseconds;

    setState(() {
      testResults = results.map((e) => e.toString()).toList();
    });
  }

  // Função para classificar uma nova amostra
  void classifyNewSample() {
    if (knn == null) {
      return;
    }
    // Convertendo a entrada do usuário para uma lista de doubles
    List<double> newSample = newSampleController.text
        .split(',')
        .map((e) => double.parse(e.trim()))
        .toList();

    // Classificar a nova amostra
    int result = knn!.predict(newSample);

    setState(() {
      predictedLabel = result.toString();
    });
  }

  // Função para calcular a acurácia
  double calculateAccuracy(List<int> predictions, List<int> labels) {
    int correct = 0;
    for (int i = 0; i < predictions.length; i++) {
      if (predictions[i] == labels[i]) {
        correct++;
      }
    }
    return correct / predictions.length;
  }

  // Função para calcular a precisão
  double calculatePrecision(List<int> predictions, List<int> labels) {
    int truePositives = 0;
    int falsePositives = 0;

    for (int i = 0; i < predictions.length; i++) {
      if (predictions[i] == 1 && labels[i] == 1) {
        truePositives++;
      } else if (predictions[i] == 1 && labels[i] == 0) {
        falsePositives++;
      }
    }

    return truePositives / (truePositives + falsePositives);
  }

  // Função para calcular o recall
  double calculateRecall(List<int> predictions, List<int> labels) {
    int truePositives = 0;
    int falseNegatives = 0;

    for (int i = 0; i < predictions.length; i++) {
      if (predictions[i] == 1 && labels[i] == 1) {
        truePositives++;
      } else if (predictions[i] == 0 && labels[i] == 1) {
        falseNegatives++;
      }
    }

    return truePositives / (truePositives + falseNegatives);
  }

  // Função para calcular o F1-score
  double calculateF1Score(double precision, double recall) {
    return 2 * (precision * recall) / (precision + recall);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('KNN Classifier'),
      ),
      body: Center(
        child: isLoading
            ? CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Pressione o botão para classificar todos os pontos de dados',
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: classifyAllPoints,
                    child: Text('Classificar Todos os Pontos'),
                  ),
                  SizedBox(height: 20),
                  testResults.isNotEmpty
                      ? Expanded(
                          child: ListView.builder(
                            itemCount: testResults.length,
                            itemBuilder: (context, index) {
                              return ListTile(
                                title: Text(
                                    'Ponto ${index + 1}: ${testResults[index]}'),
                              );
                            },
                          ),
                        )
                      : Container(),
                  SizedBox(height: 20),
                  Text(
                    'Acurácia: ${(accuracy * 100).toStringAsFixed(2)}%',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    'Precisão: ${(precision * 100).toStringAsFixed(2)}%',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    'Recall: ${(recall * 100).toStringAsFixed(2)}%',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    'F1 Score: ${(f1Score * 100).toStringAsFixed(2)}%',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Tempo de execução do KNN: $knnTime ms',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Tempo de cálculo da Acurácia: $accuracyTime ms',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Tempo de cálculo da Precisão: $precisionTime ms',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Tempo de cálculo do Recall: $recallTime ms',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'Tempo de cálculo do F1 Score: $f1ScoreTime ms',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SizedBox(height: 20),
                  TextField(
                    controller: newSampleController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Nova Amostra (separada por vírgulas)',
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: classifyNewSample,
                    child: Text('Classificar Nova Amostra'),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Rótulo Previsto para Nova Amostra: $predictedLabel',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
      ),
    );
  }
}
