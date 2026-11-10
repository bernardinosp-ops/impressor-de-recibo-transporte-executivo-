/// Modelos de dados: motorista (emitente) e recibo.
library;

class Motorista {
  const Motorista({
    this.nome = '',
    this.documento = '',
    this.telefone = '',
    this.email = '',
    this.endereco = '',
    this.cidade = '',
    this.veiculo = '',
    this.cor = '',
    this.placa = '',
    this.chavePix = '',
  });

  /// Nome do motorista ou razão social.
  final String nome;

  /// CPF ou CNPJ do emitente.
  final String documento;
  final String telefone;
  final String email;
  final String endereco;

  /// Cidade usada na linha "Cidade, dd de mês de aaaa".
  final String cidade;
  final String veiculo;
  final String cor;
  final String placa;
  final String chavePix;

  bool get completo => nome.trim().isNotEmpty && documento.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'documento': documento,
        'telefone': telefone,
        'email': email,
        'endereco': endereco,
        'cidade': cidade,
        'veiculo': veiculo,
        'cor': cor,
        'placa': placa,
        'chavePix': chavePix,
      };

  factory Motorista.fromJson(Map<String, dynamic> j) => Motorista(
        nome: j['nome'] as String? ?? '',
        documento: j['documento'] as String? ?? '',
        telefone: j['telefone'] as String? ?? '',
        email: j['email'] as String? ?? '',
        endereco: j['endereco'] as String? ?? '',
        cidade: j['cidade'] as String? ?? '',
        veiculo: j['veiculo'] as String? ?? '',
        cor: j['cor'] as String? ?? '',
        placa: j['placa'] as String? ?? '',
        chavePix: j['chavePix'] as String? ?? '',
      );
}

class Recibo {
  const Recibo({
    required this.numero,
    required this.emissao,
    required this.passageiro,
    this.documento = '',
    this.empresa = '',
    this.dataViagem,
    this.hora = '',
    this.origem = '',
    this.destino = '',
    this.km = '',
    this.valorCorrida = 0,
    this.pedagio = 0,
    this.estacionamento = 0,
    this.outros = 0,
    this.pagamento = '',
    this.observacoes = '',
  });

  final int numero;
  final DateTime emissao;
  final String passageiro;
  final String documento;
  final String empresa;
  final DateTime? dataViagem;
  final String hora;
  final String origem;
  final String destino;
  final String km;

  /// Valores em centavos.
  final int valorCorrida;
  final int pedagio;
  final int estacionamento;
  final int outros;
  final String pagamento;
  final String observacoes;

  int get total => valorCorrida + pedagio + estacionamento + outros;

  String get numeroFormatado => numero.toString().padLeft(6, '0');

  Map<String, dynamic> toJson() => {
        'numero': numero,
        'emissao': emissao.toIso8601String(),
        'passageiro': passageiro,
        'documento': documento,
        'empresa': empresa,
        'dataViagem': dataViagem?.toIso8601String(),
        'hora': hora,
        'origem': origem,
        'destino': destino,
        'km': km,
        'valorCorrida': valorCorrida,
        'pedagio': pedagio,
        'estacionamento': estacionamento,
        'outros': outros,
        'pagamento': pagamento,
        'observacoes': observacoes,
      };

  factory Recibo.fromJson(Map<String, dynamic> j) => Recibo(
        numero: j['numero'] as int,
        emissao: DateTime.parse(j['emissao'] as String),
        passageiro: j['passageiro'] as String? ?? '',
        documento: j['documento'] as String? ?? '',
        empresa: j['empresa'] as String? ?? '',
        dataViagem: j['dataViagem'] == null ? null : DateTime.parse(j['dataViagem'] as String),
        hora: j['hora'] as String? ?? '',
        origem: j['origem'] as String? ?? '',
        destino: j['destino'] as String? ?? '',
        km: j['km'] as String? ?? '',
        valorCorrida: j['valorCorrida'] as int? ?? 0,
        pedagio: j['pedagio'] as int? ?? 0,
        estacionamento: j['estacionamento'] as int? ?? 0,
        outros: j['outros'] as int? ?? 0,
        pagamento: j['pagamento'] as String? ?? '',
        observacoes: j['observacoes'] as String? ?? '',
      );
}
