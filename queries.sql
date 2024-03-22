/*---------------------------------------------------------------------------------------------------------------------
                                    EXCLUSÕES
---------------------------------------------------------------------------------------------------------------------*/
DROP TABLE vendas;
DROP TABLE produtos;
DROP TABLE estoque;

/*---------------------------------------------------------------------------------------------------------------------
                                    TABELAS
---------------------------------------------------------------------------------------------------------------------*/

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

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO TRIGGER criar_produto
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION criar_produto ()
    RETURNS TRIGGER AS $$
        BEGIN
            INSERT INTO produtos (nome, preco)
                VALUES (NEW.produto, calcular_preco(NEW.quantidade, NEW.custo, NEW.lucro));
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql;

/*---------------------------------------------------------------------------------------------------------------------
                                    TRIGGER trigger_criar_produto
---------------------------------------------------------------------------------------------------------------------*/

CREATE TRIGGER trigger_create_produto
    AFTER INSERT ON estoque
    FOR EACH ROW
    EXECUTE FUNCTION criar_produto();

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO TRIGGER atualizar_quantidade_em_estoque
---------------------------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE FUNCTION atualizar_quantidade_em_estoque()
    RETURNS TRIGGER AS $$
        BEGIN
            UPDATE estoque
                SET quantidade = quantidade - NEW.quantidade
                WHERE produto = NEW.produto;
            RETURN NEW;
        END;
    $$ LANGUAGE plpgsql;

/*---------------------------------------------------------------------------------------------------------------------
                                    TRIGGER trigger_quantidade_em_estoque
---------------------------------------------------------------------------------------------------------------------*/

CREATE TRIGGER trigger_quantidade_em_estoque
    AFTER INSERT ON vendas
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_quantidade_em_estoque();

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO calcular_preco
---------------------------------------------------------------------------------------------------------------------*/

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

/*########           TESTES           ########*/
SELECT * FROM calcular_preco(100, 100, 50);

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO calcular_valor_da_venda
---------------------------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE FUNCTION calcular_valor_da_venda(preco NUMERIC, quantidade INTEGER, desconto NUMERIC DEFAULT NULL)
    RETURNS NUMERIC AS $$
        DECLARE
            valor NUMERIC;
        BEGIN
            IF desconto IS NOT NULL
                THEN
                valor := preco - (preco * (desconto / 100));
                valor := valor * quantidade;
            ELSE
                valor := preco * quantidade;
            END IF;
            RETURN ROUND(valor, 2);
        END;
    $$ LANGUAGE plpgsql;

SELECT * FROM calcular_valor_da_venda(1.5, 2);
/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO registrar_produto_no_estoque
---------------------------------------------------------------------------------------------------------------------*/

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

/*########           TESTES           ########*/
SELECT * FROM registrar_produto_no_estoque('laranja', 500, 750, 35, '2024-03-21');

SELECT * FROM estoque;

SELECT * FROM produtos;

SELECT e.produto, e.quantidade, e.custo, e.lucro, p.preco
    FROM estoque as e
    JOIN produtos as p
    ON e.produto = p.nome;

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO registrar_venda
---------------------------------------------------------------------------------------------------------------------*/

CREATE OR REPLACE FUNCTION registrar_venda(_produto VARCHAR, _quantidade INTEGER, desconto NUMERIC DEFAULT NULL)
    RETURNS BOOLEAN AS $$
        DECLARE
            existe BOOLEAN;
            _preco NUMERIC;
        BEGIN
            SELECT p.preco, TRUE INTO _preco, existe
                FROM produtos p
                JOIN estoque e ON e.produto = p.nome
                WHERE e.produto = _produto AND e.quantidade >= _quantidade;
            IF existe
                THEN
                    INSERT INTO vendas (produto, quantidade, valor)
                        VALUES (_produto, _quantidade, calcular_valor_da_venda(_preco, _quantidade, desconto));
                    RETURN TRUE;
            END IF;
            RETURN FALSE;
        END;
    $$ LANGUAGE plpgsql;

/*########           TESTES           ########*/
SELECT * FROM registrar_venda('laranja', 24);
SELECT * FROM registrar_venda('laranja', 24, 7);


SELECT p.nome as "produto", v.data, v.quantidade, v.valor FROM vendas as v JOIN produtos as p ON v.produto = p.nome WHERE v.produto = 'laranja';

SELECT e.produto, e.quantidade, e.custo, e.lucro, p.preco FROM estoque as e JOIN produtos as p ON e.produto = p.nome WHERE produto = 'laranja';

SELECT * FROM selecionar_produto_em_estoque('abacate');

/*---------------------------------------------------------------------------------------------------------------------
                                    FUNÇÃO selecionar_produto_em_estoque
---------------------------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE FUNCTION selecionar_produto_em_estoque(_produto VARCHAR DEFAULT NULL)
    RETURNS TABLE (produto VARCHAR, quantidade INTEGER, custo NUMERIC, lucro NUMERIC, preco NUMERIC) AS $$
        BEGIN
            IF _produto IS NOT NULL
                THEN
                    RETURN QUERY
                        SELECT e.produto, e.quantidade, e.custo, e.lucro, p.preco
                            FROM estoque e
                            JOIN produtos p
                            ON e.produto = p.nome
                        WHERE e.produto = _produto;
            ELSE
                RETURN QUERY
                    SELECT e.produto, e.quantidade, e.custo, e.lucro, p.preco
                        FROM estoque e
                        JOIN produtos p
                        ON e.produto = p.nome
                    ORDER BY e.produto;
            END IF;
        END;
    $$ LANGUAGE plpgsql;

SELECT * FROM selecionar_produto_em_estoque();
SELECT * FROM selecionar_produto_em_estoque('abacate');