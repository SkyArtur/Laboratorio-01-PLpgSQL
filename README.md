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

<hr/>