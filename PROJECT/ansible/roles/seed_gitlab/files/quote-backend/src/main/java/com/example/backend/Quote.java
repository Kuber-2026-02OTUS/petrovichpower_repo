package com.example.backend;

import jakarta.persistence.*;

@Entity
@Table(name = "quotes")
public class Quote {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String author;
    
    @Column(length = 1000)
    private String text;

    public Quote() {}
    public Quote(String author, String text) {
        this.author = author;
        this.text = text;
    }

    public Long getId() { return id; }
    public String getAuthor() { return author; }
    public String getText() { return text; }
}