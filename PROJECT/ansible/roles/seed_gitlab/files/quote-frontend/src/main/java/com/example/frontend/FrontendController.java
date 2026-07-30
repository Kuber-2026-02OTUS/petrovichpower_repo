package com.example.frontend;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.GetMapping;

@Controller
public class FrontendController {

    @Value("${backend.api.url}")
    private String backendUrl;

    @GetMapping("/")
    public String index(Model model) {
        model.addAttribute("backendUrl", backendUrl);
        return "index";
    }
}