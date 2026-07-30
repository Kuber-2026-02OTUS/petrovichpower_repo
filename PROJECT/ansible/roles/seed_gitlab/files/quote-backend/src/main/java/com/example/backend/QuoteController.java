package com.example.backend;

import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/quotes")
@CrossOrigin(origins = "*")
public class QuoteController {
    private final QuoteRepository repository;

    public QuoteController(QuoteRepository repository) {
        this.repository = repository;
    }

    @GetMapping("/random")
    public Quote getRandomQuote() {
        return repository.findRandomQuote();
    }
}