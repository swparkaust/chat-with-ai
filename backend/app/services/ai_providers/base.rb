module AiProviders
  class Base
    def complete(model:, system:, prompt:, max_tokens: 4096)
      raise NotImplementedError, "#{self.class}#complete must be implemented"
    end

    def available_models
      raise NotImplementedError, "#{self.class}#available_models must be implemented"
    end

    def provider_name
      raise NotImplementedError, "#{self.class}#provider_name must be implemented"
    end
  end
end
