<hr/>

# Laboratório PostgreSQL & PL/pgSQL

O PostgreSQL&copy; é um poderoso sistema de gerenciamento de banco de dados relacional de código aberto. Também é conhecido 
por sua confiabilidade, extensibilidade e conformidade com os padrões SQL, suporta uma ampla variedade de tipos de dados, 
incluindo tipos personalizados, e oferece recursos avançados como transações ACID, replicação, indexação avançada e 
suporte a linguagens procedurais, como a PL/pgSQL que é específica do PostgreSQL&copy; e baseada em SQL. Ela foi 
projetada para auxiliar nas tarefas de programação dentro do PostgreSQL&copy;, incorporando características procedurais 
que facilitam o controle de fluxo de programas.

Em minha abordagem utilizarei um container Docker&copy; e a documentação oficial, pode ser consultada neste 
[link](https://docs.docker.com/desktop/install/windows-install/) para auxiliar a instalação em diferentes plataformas.

Não há necessidade de se possuir um grande conhecimento em Docker&copy; para isso. Basta editar um arquivo *.yaml* como 
abaixo:
```yaml
version: "3.8"
services:
  postgres:
    container_name: postgres
    image: postgres:16.1
    restart: always
    environment:
      - POSTGRES_DB=laboratorio
      - POSTGRES_USER=estudante
      - POSTGRES_PASSWORD=212223
      - TZ=America/Sao_Paulo
    ports:
      - "5430:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data/

  pgadmin4:
    container_name: pgadmin4
    image: dpage/pgadmin4:8.4
    restart: always
    environment:
      - PGADMIN_DEFAULT_EMAIL=estudante@email.com
      - PGADMIN_DEFAULT_PASSWORD=212223
    ports:
      - "5050:80"

volumes:
  pgdata:
```
Se desejar alterar os dados contidos no exemplo, fique a vontade, do contrário, abra um terminal na pasta onde o arquivo 
está salvo e digite o comando a seguir: 
```shell
docker-compose up -d 
```
Desta forma teremos inclusive a ferramenta pgAdmin4 para realizarmos as nossas consultas e manipulações. Você poderá
acessar o pgAdmin, abrindo o seu browser em http://localhost:5050, realizar o login com o usuário e senha definidos em 
PGADMIN_DEFAULT_EMAIL e PGADMIN_DEFAULT_PASSWORD. 

Será necessário definir o servidor do banco de dados, clique [aqui](markdown/pgadmin.md) para acessar um pequeno tutorial. 

## Tabelas

Como proposta para este exercício, vamos criar três tabelas e estabeleceremos relações entre elas. Teremos uma 
tabela principal (*estoque*) e outras duas secundárias (*produtos* e *vendas*) que se relacionaram diretamente com o estoque,
mas não se relacionarão diretamente entre si.
```sql
CREATE TABLE estoque (
    produto VARCHAR(255) PRIMARY KEY,
    quantidade INTEGER,
    custo NUMERIC(11, 2),
    lucro NUMERIC,
    data DATE
);

CREATE TABLE produtos (
    nome VARCHAR(255) PRIMARY KEY,
    preco NUMERIC(11, 2),
    FOREIGN KEY (nome)
        REFERENCES estoque(produto)
        ON DELETE CASCADE
);

CREATE TABLE vendas (
    produto VARCHAR(255) NOT NULL,
    data DATE DEFAULT CURRENT_DATE,
    quantidade INTEGER,
    valor NUMERIC(11, 2),
    FOREIGN KEY (produto)
        REFERENCES estoque(produto)
        ON DELETE CASCADE
);

```

É interessante perceber que ao estabelecermos um relacionamento entre duas chaves primárias, como ocorre entre *estoque* 
e *produtos* estamos criando uma relação de um para um, (1:1 ou one-to-one), pois, ambas possui restrição de unicidade
em suas respectivas colunas. Já na tabela *vendas*, a relação estabelecida diretamente com a tabela *estoque*, e 
indiretamente com a tabela *produtos*, é de um para muitos (1:N ou ono-to-many), tendo em vista que, mesmo utilizando a 
coluna 'produto' como uma chave estrangeira, a única restrição que colocamos para ela é de não nulidade. 

## Criando uma lógica reutilizável
 As linguagens procedurais para banco de dados, além de facilitarem o fluxo do programa, como dito anteriormente, também 
permitem que, ao elaborarmos uma lógica, ela possa ser reutilizada em outros trechos de código, como em qualquer outra
linguagem de programação. Vamos então criar uma para calcular o preço a partir da quantidade de produtos comprados, 
o custo total e a margem de lucro estabelecida.

```sql
CREATE OR REPLACE FUNCTION calcular_preco(quantidade INTEGER, custo NUMERIC, lucro NUMERIC)
    RETURNS NUMERIC AS $$
        DECLARE
            preco NUMERIC;
        BEGIN
            preco :=  custo / quantidade;
            preco := preco + (preco * (lucro / 100));
            RETURN ROUND(preco, 2);
        END;
    $$ LANGUAGE plpgsql;
```
Com esta função registrada em nosso banco de dados, poderemos calcular o preço final do produto quando desejarmos.

## Triggers & funções triggers

Agora, vamos automatizar algumas ações em nosso banco de dados. Começaremos com a inserção de um produto na tabela
*produtos*, a partir do registro dele no estoque. Para isso vamos utilizar funções que serão disparadas por gatilhos.
Também vamos implementar a mesma lógica, para quando uma venda for realizada, a quantidade do produto em estoque seja
atualizada. Vamos começar com o primeiro cenário.

```sql
CREATE OR REPLACE FUNCTION criar_produto ()
    RETURNS TRIGGER AS $$
        BEGIN
            INSERT INTO produtos (nome, preco)
                VALUES (NEW.produto, calcular_preco(NEW.quantidade, NEW.custo, NEW.lucro));
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_create_produto
    AFTER INSERT ON estoque
    FOR EACH ROW
    EXECUTE FUNCTION criar_produto();
```
Com estes dispositivos, toda a vez que inserirmos um novo produto no *estoque*, ele será registrado em *produtos*, observe
como utilizamos a nossa função **calcular_preco()** para deixar o nosso código mais claro.

Para o cenário seguinte, precisaremos realizar um UPDATE em *estoque* a partir da inserção de dados em *vendas*, mas isso
não representará uma dificuldade maior, observe:

```sql
CREATE OR REPLACE FUNCTION atualizar_quantidade_em_estoque()
    RETURNS TRIGGER AS $$
        BEGIN
            UPDATE estoque
                SET quantidade = quantidade - NEW.quantidade
                WHERE produto = NEW.produto;
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_quantidade_em_estoque
    AFTER INSERT ON vendas
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_quantidade_em_estoque();
```
Pronto, lógica implementada, agora vamos seguir adiante.

## Tratamento de exceções

Definimos em nossa tabela *estoque*, que a coluna 'produto', seria uma chave primária. Isso confere a ela uma unicidade, 
de modo que não haverá outro registro com o mesmo conteúdo, na coluna em questão, na nossa tabela do banco de dados. Porém, 
se o programa que for utilizar o nosso banco de dados, tentar realizar a operação descrita acima, um erro será emitido 
pelo nosso banco. Se imaginarmos que esse erro, poderá gerar problemas de execução mais a frente, seria inteligente de nossa
parte, tomarmos alguma precaução desde agora e ao invés de permitir um erro, retornarmos um valor que possa ser computado, 
como um booleano, por exemplo. 
```sql
CREATE OR REPLACE FUNCTION registrar_produto_no_estoque(_produto VARCHAR, _quantidade INTEGER, _custo NUMERIC, _lucro NUMERIC, _data DATE)
    RETURNS BOOLEAN AS $$
        BEGIN
            INSERT INTO estoque (produto, quantidade, custo, lucro, data)
                VALUES (_produto, _quantidade, _custo, _lucro, _data);
            RETURN TRUE;
        EXCEPTION
            WHEN others
                THEN
                    RETURN FALSE;
        END;
    $$ LANGUAGE plpgsql;
```
Agora poderemos, inclusive, realizar alguns testes que nos permitirão verificar se nosso gatilho para a criação de um
registro na tabela *produtos*, a partir de outro na tabela *estoque*, está funcionando.
```shell
laboratorio=# SELECT * FROM registrar_produto_no_estoque('abacate', 100, 100, 10, '2024-03-21');
 registrar_produto_no_estoque
------------------------------
 true
(1 registro)
```
Se tentarmos novamente a mesma inserção receberemos false
```shell
laboratorio=# SELECT * FROM registrar_produto_no_estoque('abacate', 100, 100, 10, '2024-03-21');
 registrar_produto_no_estoque
------------------------------
 false
(1 registro)
```
E somente um registro foi gerado em *estoque*.
```shell
laboratorio=# SELECT * FROM estoque;
 produto | quantidade | custo  | lucro |    data
---------+------------+--------+-------+------------
 abacate |        100 | 100.00 |    10 | 2024-03-21
(2 registros)

```
Também foi criado um registro em *produtos*.
```shell
laboratorio=# SELECT * FROM produtos;
  nome   | preco
---------+-------
 abacate |  1.10
(2 registros)
```

## Declarando e utilizando variáveis

Ótimo! Agora vamos realizar uma inserção em vendas para verificar a nossa lógica de atualização de estoque. Aqui nós vamos
trabalhar com variáveis e recuperação de dados. Vamos conhecer também o sinal de atribuição utilizado em PL/pgSQL.

<hr/>