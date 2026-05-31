import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cpf_cnpj_validator/cpf_validator.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // PROTEÇÃO EXTRA
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- CONFIGURAÇÃO DO APP CHECK (RECAPTCHA) ---
  await FirebaseAppCheck.instance.activate(
    // Substitua o texto abaixo pela sua "Chave do Site" gerada no Google reCAPTCHA
    webProvider: ReCaptchaV3Provider('6LcAM30sAAAAAPXlaa_ybgRjAGIG3i4UzSIImxiG'),
  );

  runApp(const MaterialApp(
    home: PaginaLogin(), 
    debugShowCheckedModeBanner: false,
    title: "Rainha do Rodeio 2026",
  ));
}

// --- TELA DE LOGIN ---
class PaginaLogin extends StatefulWidget {
  const PaginaLogin({super.key});
  @override
  State<PaginaLogin> createState() => _PaginaLoginState();
}

class _PaginaLoginState extends State<PaginaLogin> {
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _cpfController = TextEditingController();
  bool _carregando = false; 

  var mascaraCPF = MaskTextInputFormatter(mask: '###.###.###-##', filter: {"#": RegExp(r'[0-9]')});

  void entrarParaVotar() async {
    String nome = _nomeController.text.trim();
    String cpfLimpo = mascaraCPF.getUnmaskedText();

    // 1. ACESSO ADMIN
    if (nome.toLowerCase() == "admin" && cpfLimpo == "00000000000") {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const TelaApuracao()));
      return; 
    }

    // 2. VALIDAÇÃO DE NOME COMPLETO
    if (nome.split(' ').length < 2) {
      _alerta("NOME INCOMPLETO", "Por favor, digite seu nome e sobrenome.", Colors.orange);
      return;
    }

    // 3. VALIDAÇÃO DE CPF
    if (!CPFValidator.isValid(_cpfController.text)) {
      _alerta("CPF INVÁLIDO", "Digite um documento real para participar.", Colors.red);
      return;
    }

    setState(() => _carregando = true);

    try {
      // Verifica se o CPF já votou antes de deixar entrar
      var consulta = await FirebaseFirestore.instance.collection('votos').doc(cpfLimpo).get();
      if (consulta.exists) {
        _alerta("BLOQUEADO", "Este CPF já registrou um voto!", Colors.redAccent);
      } else {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => TelaVotacao(nomeUsuario: nome, cpfUsuario: cpfLimpo))
        );
      }
    } catch (e) {
      _alerta("ERRO", "Falha de conexão. Verifique o App Check.", Colors.red);
    } finally {
      setState(() => _carregando = false);
    }
  }

  void _alerta(String t, String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$t: $m"), backgroundColor: c));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  'https://images.pexels.com/photos/3052731/pexels-photo-3052731.jpeg?auto=compress&cs=tinysrgb&w=600', 
                  height: 180, width: double.infinity, fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 25),
              const Text("RODEIO 2026", style: TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2)),
              const Text("Votação Oficial da Rainha", style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 40),
              
              _campo("Nome Completo", Icons.person_outline, _nomeController, null),
              const SizedBox(height: 20),
              _campo("CPF", Icons.badge_outlined, _cpfController, [mascaraCPF]),
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity, height: 55, 
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber, foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 8,
                  ), 
                  onPressed: _carregando ? null : entrarParaVotar, 
                  child: _carregando 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text("ENTRAR PARA VOTAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                )
              ),

              const SizedBox(height: 50),

              // Painel de Segurança Visual
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user, color: Colors.greenAccent, size: 22),
                        SizedBox(width: 10),
                        Text("VOTAÇÃO PROTEGIDA POR RECAPTCHA", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Cada voto é validado individualmente. O uso de robôs ou scripts de votação em massa é bloqueado automaticamente.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _campo(String l, IconData i, TextEditingController c, List<MaskTextInputFormatter>? f) {
    return TextField(
      controller: c, inputFormatters: f, style: const TextStyle(color: Colors.white), 
      decoration: InputDecoration(
        labelText: l, labelStyle: const TextStyle(color: Colors.amber), 
        prefixIcon: Icon(i, color: Colors.amber), filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.white24), borderRadius: BorderRadius.circular(15)),
        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.amber), borderRadius: BorderRadius.circular(15)),
      )
    );
  }
}

// --- TELA DE VOTAÇÃO ---
class TelaVotacao extends StatelessWidget {
  final String nomeUsuario;
  final String cpfUsuario;
  const TelaVotacao({super.key, required this.nomeUsuario, required this.cpfUsuario});

  @override
  Widget build(BuildContext context) {
    // Lista de Candidatas (Fácil de atualizar)
    final List<Map<String, String>> candidatas = [
      {"nome": "Ana Silva", "foto": "https://images.pexels.com/photos/1587009/pexels-photo-1587009.jpeg?auto=compress&cs=tinysrgb&w=300"},
      {"nome": "Beatriz Oliveira", "foto": "https://images.pexels.com/photos/1468379/pexels-photo-1468379.jpeg?auto=compress&cs=tinysrgb&w=300"},
      {"nome": "Carla Santos", "foto": "https://images.pexels.com/photos/1181686/pexels-photo-1181686.jpeg?auto=compress&cs=tinysrgb&w=300"},
      {"nome": "Daniela Lima", "foto": "https://images.pexels.com/photos/774909/pexels-photo-774909.jpeg?auto=compress&cs=tinysrgb&w=300"},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Escolha sua Rainha"), 
        backgroundColor: Colors.black, centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.share, color: Colors.amber), onPressed: () => _compartilharApp())],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(15),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200, childAspectRatio: 0.7, crossAxisSpacing: 10, mainAxisSpacing: 10
        ),
        itemCount: candidatas.length,
        itemBuilder: (context, index) => _CardCandidata(
          nome: candidatas[index]['nome']!, 
          foto: candidatas[index]['foto']!, 
          aoVotar: () => _confirmarVoto(context, candidatas[index]['nome']!)
        ),
      ),
    );
  }

  void _compartilharApp() {
    Share.share('🤠 Vote na Rainha do Rodeio 2026! Acesse: [SEU_LINK_AQUI]');
  }

  void _confirmarVoto(BuildContext context, String candidata) async {
    try {
      // ENVIO SEGURO PARA O FIREBASE
      await FirebaseFirestore.instance.collection('votos').doc(cpfUsuario).set({
        'nomeEleitor': nomeUsuario.toUpperCase(),
        'candidata': candidata,
        'data': FieldValue.serverTimestamp(), // Horário oficial do servidor (Impossível fraudar)
      });
      
      showDialog(
        context: context, barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 60),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Voto Confirmado!", style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text("Você votou em $candidata.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _compartilharApp,
                icon: const Icon(Icons.share),
                label: const Text("CONVIDAR AMIGOS"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), 
              child: const Text("SAIR", style: TextStyle(color: Colors.grey))
            )
          ]
        )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Erro: Voto não processado pelas regras de segurança.")));
    }
  }
}

// --- CARD ANIMADO ---
class _CardCandidata extends StatefulWidget {
  final String nome; final String foto; final VoidCallback aoVotar;
  const _CardCandidata({required this.nome, required this.foto, required this.aoVotar});
  @override
  State<_CardCandidata> createState() => _CardCandidataState();
}

class _CardCandidataState extends State<_CardCandidata> {
  bool _focado = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _focado = true),
      onExit: (_) => setState(() => _focado = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _focado ? Colors.amber : Colors.transparent, width: 2),
          boxShadow: _focado ? [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 10)] : [],
        ),
        child: Card(
          margin: EdgeInsets.zero, color: const Color(0xFF1E1E1E), clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          child: Column(children: [
            Expanded(child: Image.network(widget.foto, fit: BoxFit.cover, width: double.infinity)),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(widget.nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                onPressed: widget.aoVotar, child: const Text("VOTAR", style: TextStyle(fontSize: 12)),
              ),
            )
          ]),
        ),
      ),
    );
  }
}

// --- TELA DE APURAÇÃO (ADMIN) ---
class TelaApuracao extends StatelessWidget {
  const TelaApuracao({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text("RESULTADO FINAL"), backgroundColor: Colors.amber, foregroundColor: Colors.black),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('votos').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Nenhum voto registrado.", style: TextStyle(color: Colors.white)));

          Map<String, int> contagem = {};
          int totalVotos = 0;
          for (var doc in snapshot.data!.docs) {
            var dados = doc.data() as Map<String, dynamic>;
            String nome = dados['candidata'];
            contagem[nome] = (contagem[nome] ?? 0) + 1;
            totalVotos++;
          }

          var ranking = contagem.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: ranking.length,
            itemBuilder: (context, index) {
              String nome = ranking[index].key;
              int votos = ranking[index].value;
              double porcentagem = (votos / totalVotos) * 100;
              
              Color cor = Colors.white;
              String titulo = "Candidata";
              if (index == 0) { cor = Colors.amber; titulo = "👑 RAINHA"; }
              else if (index == 1) { cor = Colors.grey; titulo = "🥈 PRINCESA"; }
              else if (index == 2) { cor = Colors.brown; titulo = "🥉 MADRINHA"; }

              return Card(
                color: const Color(0xFF1E1E1E),
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  leading: Text("${index + 1}º", style: TextStyle(color: cor, fontSize: 20, fontWeight: FontWeight.bold)),
                  title: Text(nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(titulo, style: TextStyle(color: cor)),
                  trailing: Text("$votos votos (${porcentagem.toStringAsFixed(1)}%)", style: const TextStyle(color: Colors.amber)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}