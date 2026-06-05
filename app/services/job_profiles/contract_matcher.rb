module JobProfiles
  # Auto-links a company's contracts to job profiles by matching the
  # contract position against the profile name (accent/case-insensitive).
  class ContractMatcher
    Result = Struct.new(:matched, :unmatched, keyword_init: true)

    def initialize(company)
      @company = company
    end

    def match_all!
      matched = 0
      unmatched = 0

      unassigned_contracts.find_each do |contract|
        profile = find_profile_for(contract)
        if profile
          contract.update_column(:job_profile_id, profile.id)
          matched += 1
        else
          unmatched += 1
        end
      end

      Result.new(matched: matched, unmatched: unmatched)
    end

    private

    def unassigned_contracts
      Contract.joins(:employee)
              .where(employees: { company_id: @company.id }, job_profile_id: nil)
    end

    def find_profile_for(contract)
      key = normalize(contract.position)
      return nil if key.blank?

      profiles_by_name[key] ||
        profiles_index.find { |name, _| name.include?(key) || key.include?(name) }&.last
    end

    def profiles_by_name
      @profiles_by_name ||= @company.job_profiles.each_with_object({}) do |profile, hash|
        hash[normalize(profile.name)] = profile
      end
    end

    def profiles_index
      @profiles_index ||= profiles_by_name.to_a
    end

    def normalize(value)
      I18n.transliterate(value.to_s).downcase.gsub(/[^a-z0-9]+/, " ").strip
    end
  end
end
